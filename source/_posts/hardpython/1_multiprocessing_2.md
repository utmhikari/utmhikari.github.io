---
title: 【Hard Python】【第一章-多进程】2、Pipe和Queue，进程间通信
date: 2022/01/22 19:05:02
categories:
- Hard Python
tags:
- python
- multiprocessing
- pipe
- queue
- 进程通信
---

[第一话](https://utmhikari.top/2022/01/16/hardpython/1_multiprocessing_1/)详细讲解了Process新进程是如何被创建的，接下来就来讲一下进程之间有什么通信的方法。

要在`multiprocessing`中实现进程间通信，最直接的方法是采用`Pipe`或者`Queue`。其用法如下：

<!-- more -->

```python
from multiprocessing import Process, Pipe, Queue
import time
from mp_module import log, seg


def _test_queue(q):
    while True:
        msg = q.get()
        if msg == 'quit':
            break
        else:
            log(f'recv: {msg}')
    log('child process end~')


def test_queue():
    seg('test queue start')
    q = Queue()
    p = Process(target=_test_queue, args=(q,))
    p.start()
    cmds = ['helloworld', 'testmsg', 'quit']
    for cmd in cmds:
        log(f'send: {cmd}')
        q.put(cmd)
        time.sleep(1)
    assert not p.is_alive()
    seg('test queue end')


def _test_pipe(r):
    while True:
        msg = r.recv()
        if msg == 'quit':
            break
        else:
            log(f'recv: {msg}')
    log('child process end~')


def test_pipe():
    seg('test pipe start')
    r, w = Pipe()
    p = Process(target=_test_pipe, args=(r,))
    p.start()
    cmds = ['helloworld', 'testmsg', 'quit']
    for cmd in cmds:
        log(f'send: {cmd}')
        w.send(cmd)
        time.sleep(1)
    assert not p.is_alive()
    seg('test pipe end')
```

形式上非常简单。`Pipe`创建了一对`reader`跟`writer`，将`reader`传入子进程，主进程在`writer`写入数据，子进程即能通过`reader`读取到；`Queue`则更为方便，其实例能够直接传入子进程。主进程调用`put`即可写入数据，子进程调用`get`即可获取数据。

首先我们先看`Pipe`在windows下的实现：

```python
    def Pipe(duplex=True):
        '''
        Returns pair of connection objects at either end of a pipe
        '''
        address = arbitrary_address('AF_PIPE')
        if duplex:
            openmode = _winapi.PIPE_ACCESS_DUPLEX
            access = _winapi.GENERIC_READ | _winapi.GENERIC_WRITE
            obsize, ibsize = BUFSIZE, BUFSIZE
        else:
            openmode = _winapi.PIPE_ACCESS_INBOUND
            access = _winapi.GENERIC_WRITE
            obsize, ibsize = 0, BUFSIZE

        h1 = _winapi.CreateNamedPipe(
            address, openmode | _winapi.FILE_FLAG_OVERLAPPED |
            _winapi.FILE_FLAG_FIRST_PIPE_INSTANCE,
            _winapi.PIPE_TYPE_MESSAGE | _winapi.PIPE_READMODE_MESSAGE |
            _winapi.PIPE_WAIT,
            1, obsize, ibsize, _winapi.NMPWAIT_WAIT_FOREVER,
            # default security descriptor: the handle cannot be inherited
            _winapi.NULL
            )
        h2 = _winapi.CreateFile(
            address, access, 0, _winapi.NULL, _winapi.OPEN_EXISTING,
            _winapi.FILE_FLAG_OVERLAPPED, _winapi.NULL
            )
        _winapi.SetNamedPipeHandleState(
            h2, _winapi.PIPE_READMODE_MESSAGE, None, None
            )

        overlapped = _winapi.ConnectNamedPipe(h1, overlapped=True)
        _, err = overlapped.GetOverlappedResult(True)
        assert err == 0

        c1 = PipeConnection(h1, writable=duplex)
        c2 = PipeConnection(h2, readable=duplex)

        return c1, c2
```

`h1`与`h2`互为服务端/客户端的关系。`h1`通过`CreateNamedPipe`创建，之后`h2`通过`CreateFile`连接到`h1`的`NamedPipe`上。之后用`PipeConnection`封装`h1`和`h2`两端，返回`reader`跟`writer`。当然，两个管道入口是否双工也是可选项。

经过`PipeConnection`的封装，管道即拥有了发送或接收`python`对象的方法。`python`对象的序列化/反序列化会用内置库`pickle`来支持。被`pickle`的对象会保留特定的信息，比如某个模块`def`的函数，在`pickle`时除了对函数本身进行序列化外，也会封存函数所属模块的信息。在`unpickle`时，如果找不到对应模块的信息，就会报错。因此多进程之间通信python对象时，需要留意序列化/反序列化后对应对象的取值/模块环境等情况。[pickle的官方文档](https://docs.python.org/zh-cn/3/library/pickle.html)给到了我们足够的信息去了解这些机制。

接下来我们转向`Queue`的实现。相对于`Pipe`，`Queue`是对其的封装，并提供了更多的功能。这里我们完整列举一下`Queue`的关键代码：：

```python
class Queue(object):
    def __init__(self, maxsize=0, *, ctx):
        if maxsize <= 0:
            from .synchronize import SEM_VALUE_MAX as maxsize
        self._maxsize = maxsize
        self._reader, self._writer = connection.Pipe(duplex=False)
        self._rlock = ctx.Lock()
        self._opid = os.getpid()
        if sys.platform == 'win32':
            self._wlock = None
        else:
            self._wlock = ctx.Lock()
        self._sem = ctx.BoundedSemaphore(maxsize)
        self._ignore_epipe = False
        self._reset()
        if sys.platform != 'win32':
            register_after_fork(self, Queue._after_fork)

    def __getstate__(self):
        context.assert_spawning(self)
        return (self._ignore_epipe, self._maxsize, self._reader, self._writer,
                self._rlock, self._wlock, self._sem, self._opid)

    def __setstate__(self, state):
        (self._ignore_epipe, self._maxsize, self._reader, self._writer,
         self._rlock, self._wlock, self._sem, self._opid) = state
        self._reset()

    def _reset(self, after_fork=False):
        if after_fork:
            self._notempty._at_fork_reinit()
        else:
            self._notempty = threading.Condition(threading.Lock())
        self._buffer = collections.deque()
        self._thread = None
        self._jointhread = None
        self._joincancelled = False
        self._closed = False
        self._close = None
        self._send_bytes = self._writer.send_bytes
        self._recv_bytes = self._reader.recv_bytes
        self._poll = self._reader.poll

    def put(self, obj, block=True, timeout=None):
        if self._closed:
            raise ValueError(f"Queue {self!r} is closed")
        if not self._sem.acquire(block, timeout):
            raise Full

        with self._notempty:
            if self._thread is None:
                self._start_thread()
            self._buffer.append(obj)
            self._notempty.notify()

    def get(self, block=True, timeout=None):
        if self._closed:
            raise ValueError(f"Queue {self!r} is closed")
        if block and timeout is None:
            with self._rlock:
                res = self._recv_bytes()
            self._sem.release()
        else:
            if block:
                deadline = time.monotonic() + timeout
            if not self._rlock.acquire(block, timeout):
                raise Empty
            try:
                if block:
                    timeout = deadline - time.monotonic()
                    if not self._poll(timeout):
                        raise Empty
                elif not self._poll():
                    raise Empty
                res = self._recv_bytes()
                self._sem.release()
            finally:
                self._rlock.release()
        return _ForkingPickler.loads(res)

    def close(self):
        self._closed = True
        try:
            self._reader.close()
        finally:
            close = self._close
            if close:
                self._close = None
                close()

    def _start_thread(self):
        self._buffer.clear()
        self._thread = threading.Thread(
            target=Queue._feed,
            args=(self._buffer, self._notempty, self._send_bytes,
                  self._wlock, self._writer.close, self._ignore_epipe,
                  self._on_queue_feeder_error, self._sem),
            name='QueueFeederThread'
        )
        self._thread.daemon = True
        self._thread.start()
        if not self._joincancelled:
            self._jointhread = Finalize(
                self._thread, Queue._finalize_join,
                [weakref.ref(self._thread)],
                exitpriority=-5
                )
        self._close = Finalize(
            self, Queue._finalize_close,
            [self._buffer, self._notempty],
            exitpriority=10
            )

    @staticmethod
    def _feed(buffer, notempty, send_bytes, writelock, close, ignore_epipe,
              onerror, queue_sem):
        debug('starting thread to feed data to pipe')
        nacquire = notempty.acquire
        nrelease = notempty.release
        nwait = notempty.wait
        bpopleft = buffer.popleft
        sentinel = _sentinel
        if sys.platform != 'win32':
            wacquire = writelock.acquire
            wrelease = writelock.release
        else:
            wacquire = None

        while 1:
            try:
                nacquire()
                try:
                    if not buffer:
                        nwait()
                finally:
                    nrelease()
                try:
                    while 1:
                        obj = bpopleft()
                        if obj is sentinel:
                            debug('feeder thread got sentinel -- exiting')
                            close()
                            return
                        obj = _ForkingPickler.dumps(obj)
                        if wacquire is None:
                            send_bytes(obj)
                        else:
                            wacquire()
                            try:
                                send_bytes(obj)
                            finally:
                                wrelease()
                except IndexError:
                    pass
            except Exception as e:
                if ignore_epipe and getattr(e, 'errno', 0) == errno.EPIPE:
                    return
                if is_exiting():
                    info('error in queue thread: %s', e)
                    return
                else:
                    queue_sem.release()
                    onerror(e, obj)
```

在`Queue`的`__init__`函数中，构造了这么些对象：

- `self._maxsize`：`Queue`队列的最大长度
- `self._reader`, `self._writer`：`pipe`的两端
- `self._rlock`：`self._reader`的读锁
- `self._wlock`：`self._writer`的写锁
- `self._sem`：以`self._maxsize`为基准的信号量，用来记录队列填满情况
- `self._notempty`：队列非空的条件变量。如果队列为空，需要`wait`
- `self._buffer`：存储`python`对象的队列`deque`
- `self._thread`：消费线程，用于消费`self._buffer`中的内容并发送到`pipe`中
- `self._jointhread`：关闭消费线程的`finalizer`
- `self._close`：关闭`pipe`的`finalizer`

其中还要留意一点是，`Queue`实例本身是要传给`Process`实例，并在另一个进程被反序列化一次。因此为了保证序列化/反序列化之后部分状态得到保留（比如`pipe`），`Queue`的类定义中采用了`__getstate__`和`__setstate__`两个钩子去实现实例内部状态的存储与读取。这个特性在`pickle`的官方文档内有详细的说明。

大致了解了这些对象的含义后，接下来，就详细把`Queue`的工作流程列一下：

- 用户调用`put`，信号量`self._sem`增加一个占位，之后发现消费线程未启动，通过`self._start_thread`启动消费线程`Queue._feed`
- 消费线程进入循环，发现队列`self._buffer`为空，条件变量`self._notempty`进入`wait`
- `self._start_thread`之后，将`python`对象推入`self._buffer`，并`notify`条件变量`self._notempty`
  - 这一步很有概率发生在上一步之前，不过无所谓了
- `_feed`退出`wait`状态，`pop`出`python`对象，然后将其`pickle`，最后调用`self._writer._send_bytes`发送序列化之后的数据到`pipe`内
  - 这里注意，如果`python`对象是`object()`，会触发`self._writer.close`。因此实际业务代码中最好不要出现发送`object()`的情况
- 用户调用`get`，通过`self._reader`读取`pipe`中的数据，并且让信号量`self._sem`释放一个占位。之后对数据进行反序列化，得到发送过来的对象
- 用户调用`close`，首先关闭`self._reader`，然后在`self._writer`中发送一个`object()`。`_feed`会一直消费队列，直到检测到最后的`object()`，终于触发`self._writer`的关闭。这样`pipe`的两端就都关闭，并且`buffer`里也没有任何其它数据了。
- 用户调用`join_thread`，触发`self._thread.join()`，关闭消费线程

在`multiprocessing`当中，`Queue`还有两种变体，分别为`SimpleQueue`和`JoinableQueue`。`SimpleQueue`没有提供`blocking`或`timeout`的功能，只是简单创建一对`pipe`交换序列化的数据。`JoinableQueue`则是在`Queue`的基础上增加了`join`的功能，其实现上是增加了一个初始值0的信号量`_unfinished_tasks`以及一个条件变量`_cond`。`JoinableQueue`在调用`join`时，如果`_unfinished_tasks`信号量不为0会进入`_cond.wait`，这是因为每次`put`的时候`_unfinished_tasks`信号量会`release`一次，只有用户每次`get`之后显式调用`JoinableQueue.task_done`才能`acquire`一次信号量，最终使得`_unfinished_tasks`信号量归零并`notify_all`所有`join`的调用。

最后，进程间通信的方法说到底，除了`Pipe`跟`Queue`外，采用`Manager`共享内存或者直接用`socket`网络通信都是ok的方式。当然，如果是在单节点上面，并且是一个内聚的`python`项目的话，`Queue`是不二选择。
