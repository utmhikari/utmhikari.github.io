---
title: 【Hard Python】【第二章-异步IO】2、异步任务在事件循环中的执行
date: 2022/02/20 19:22:53
categories:
- Hard Python
tags:
- python
- asyncio
- 事件循环
- proactor
- 异步
---

接续[第一话](https://utmhikari.top/2022/02/12/hardpython/2_asyncio_1/)的内容，事件循环在创建之后，又是如何运行协程任务以及异步IO任务的？
​
由`asyncio.run`的代码可知，`loop.run_until_complete`是运行协程的方法。其定义如下：

<!-- more -->

```python
# base_events.py
class BaseEventLoop(events.AbstractEventLoop):
    def run_until_complete(self, future):
        self._check_closed()
        self._check_running()
        new_task = not futures.isfuture(future)
        future = tasks.ensure_future(future, loop=self)
        if new_task:
            future._log_destroy_pending = False
        future.add_done_callback(_run_until_complete_cb)
        try:
            self.run_forever()
        except:
            if new_task and future.done() and not future.cancelled():
                future.exception()
            raise
        finally:
            future.remove_done_callback(_run_until_complete_cb)
        if not future.done():
            raise RuntimeError('Event loop stopped before Future completed.')
        return future.result()
    

# tasks.py
def ensure_future(coro_or_future, *, loop=None):
    return _ensure_future(coro_or_future, loop=loop)


def _ensure_future(coro_or_future, *, loop=None):
    if futures.isfuture(coro_or_future):
        if loop is not None and loop is not futures._get_loop(coro_or_future):
            raise ValueError('The future belongs to a different loop than '
                            'the one specified as the loop argument')
        return coro_or_future

    if not coroutines.iscoroutine(coro_or_future):
        if inspect.isawaitable(coro_or_future):
            coro_or_future = _wrap_awaitable(coro_or_future)
        else:
            raise TypeError('An asyncio.Future, a coroutine or an awaitable '
                            'is required')

    if loop is None:
        loop = events._get_event_loop(stacklevel=4)
    return loop.create_task(coro_or_future)
```

`run_until_complete`方法传入的协程会通过`tasks.ensure_future`方法被封装成一个`task`实例，从上述的代码可以看到，最终落实到了`loop.create_task`方法。
​

```python
# base_events.py
class BaseEventLoop(events.AbstractEventLoop):
    def create_task(self, coro, *, name=None):
        self._check_closed()
        if self._task_factory is None:
            task = tasks.Task(coro, loop=self, name=name)
            if task._source_traceback:
                del task._source_traceback[-1]
        else:
            task = self._task_factory(self, coro)
            tasks._set_task_name(task, name)

        return task
    

# task.py
class Task(futures._PyFuture):
    def __init__(self, coro, *, loop=None, name=None):
        super().__init__(loop=loop)
        if self._source_traceback:
            del self._source_traceback[-1]
        if not coroutines.iscoroutine(coro):
            self._log_destroy_pending = False
            raise TypeError(f"a coroutine was expected, got {coro!r}")

        if name is None:
            self._name = f'Task-{_task_name_counter()}'
        else:
            self._name = str(name)

        self._must_cancel = False
        self._fut_waiter = None
        self._coro = coro
        self._context = contextvars.copy_context()

        self._loop.call_soon(self.__step, context=self._context)
        _register_task(self)


# base_events.py
class BaseEventLoop(events.AbstractEventLoop):
    def call_soon(self, callback, *args, context=None):
        self._check_closed()
        if self._debug:
            self._check_thread()
            self._check_callback(callback, 'call_soon')
        handle = self._call_soon(callback, args, context)
        if handle._source_traceback:
            del handle._source_traceback[-1]
        return handle
    
    def _call_soon(self, callback, args, context):
        handle = events.Handle(callback, args, self, context)
        if handle._source_traceback:
            del handle._source_traceback[-1]
        self._ready.append(handle)
        return handle
```

`loop.create_task`方法最终会生成一个`Task`实例。`Task`实例封装了协程以及其它一系列变量，最终调用`loop`的`call_soon`方法，传入了实例的`__step`函数。`call_soon`方法传入的函数，会通过`events.Handle`封装生成一个`handle`实例，并加入到事件循环的`_ready`队列中。
​

`__step`方法会通过`coro.send(None)`或是`coro.throw(exc)`方法启动`Task`实例内部的协程并获取协程的返回结果，对于一般协程而言`coro.send(None)`会直接`throw`一个`StopIteration`异常，并在异常结果里附上协程返回值。当然，也有其它情况（比如`await`了一个`yield`多次的`Awaitable`实例）可能要多次`call_soon`协程`Task`的`__step`函数，相关的例子可以查看stackoverflow的[这篇文章](https://stackoverflow.com/questions/34469060/python-native-coroutines-and-send)。
​

在这之后，我们再回到`run_until_complete`方法，在`ensure_future`后，便调用`loop.run_forever`方法，启动事件循环。
​

```python
# windows_events.py
class ProactorEventLoop(proactor_events.BaseProactorEventLoop):
    def run_forever(self):
        try:
            assert self._self_reading_future is None
            self.call_soon(self._loop_self_reading)
            super().run_forever()
        finally:
            if self._self_reading_future is not None:
                ov = self._self_reading_future._ov
                self._self_reading_future.cancel()
                if ov is not None:
                    self._proactor._unregister(ov)
                self._self_reading_future = None
                
                
# proactor_events.py
class BaseProactorEventLoop(base_events.BaseEventLoop):
    def _loop_self_reading(self, f=None):
        try:
            if f is not None:
                f.result()  # may raise
            if self._self_reading_future is not f:
                return
            f = self._proactor.recv(self._ssock, 4096)
        except exceptions.CancelledError:
            return
        except (SystemExit, KeyboardInterrupt):
            raise
        except BaseException as exc:
            self.call_exception_handler({
                'message': 'Error on reading from the event loop self pipe',
                'exception': exc,
                'loop': self,
            })
        else:
            self._self_reading_future = f
            f.add_done_callback(self._loop_self_reading)


# base_events.py
class BaseEventLoop(events.AbstractEventLoop):
    def run_forever(self):
        self._check_closed()
        self._check_running()
        self._set_coroutine_origin_tracking(self._debug)
        self._thread_id = threading.get_ident()

        old_agen_hooks = sys.get_asyncgen_hooks()
        sys.set_asyncgen_hooks(firstiter=self._asyncgen_firstiter_hook,
                               finalizer=self._asyncgen_finalizer_hook)
        try:
            events._set_running_loop(self)
            while True:
                self._run_once()
                if self._stopping:
                    break
        finally:
            self._stopping = False
            self._thread_id = None
            events._set_running_loop(None)
            self._set_coroutine_origin_tracking(False)
            sys.set_asyncgen_hooks(*old_agen_hooks)
            
    def _run_once(self):
        sched_count = len(self._scheduled)
        if (sched_count > _MIN_SCHEDULED_TIMER_HANDLES and
            self._timer_cancelled_count / sched_count >
                _MIN_CANCELLED_TIMER_HANDLES_FRACTION):
            new_scheduled = []
            for handle in self._scheduled:
                if handle._cancelled:
                    handle._scheduled = False
                else:
                    new_scheduled.append(handle)

            heapq.heapify(new_scheduled)
            self._scheduled = new_scheduled
            self._timer_cancelled_count = 0
        else:
            while self._scheduled and self._scheduled[0]._cancelled:
                self._timer_cancelled_count -= 1
                handle = heapq.heappop(self._scheduled)
                handle._scheduled = False

        timeout = None
        if self._ready or self._stopping:
            timeout = 0
        elif self._scheduled:
            # Compute the desired timeout.
            when = self._scheduled[0]._when
            timeout = min(max(0, when - self.time()), MAXIMUM_SELECT_TIMEOUT)

        event_list = self._selector.select(timeout)
        self._process_events(event_list)

        end_time = self.time() + self._clock_resolution
        while self._scheduled:
            handle = self._scheduled[0]
            if handle._when >= end_time:
                break
            handle = heapq.heappop(self._scheduled)
            handle._scheduled = False
            self._ready.append(handle)

        ntodo = len(self._ready)
        for i in range(ntodo):
            handle = self._ready.popleft()
            if handle._cancelled:
                continue
            if self._debug:
                # debug模式下代码，加了时间统计
            else:
                handle._run()
        handle = None  # Needed to break cycles when an exception occurs.
```

`ProactorEventLoop`在调用`run_forever`时，首先会用`call_soon`方法将`_loop_self_reading`方法加入排期。`_loop_self_reading`方法会读取`proactor`中的`future`，并且将自己加入`future`的完成时回调，实现不间断地读取`future`实例。
​

之后，`ProactorEventLoop`调用了`BaseEventLoop`的`run_forever`方法，在其中会不断执行`_run_once`方法去一遍遍地迭代事件循环。一轮`_run_once`会做以下几件事情：

- 清理`_scheduled`中被取消的定时任务
- `select`出事件列表并进行处理
- 从`_scheduled`取出到时的任务，加入到`_ready`列表中
  - 由上面的逻辑也可知，`call_soon`的任务也会被加入到`_ready`列表中
- 从`_ready`列表中依次取出所有`handle`，调用`_run`方法运行

通过这种机制，事件循环就能持续不断地运行任务。
​
由上述`_run_once`的定义也可知，在`select`事件列表一步会出现`IOCP`的身影，这是因为`BaseProactorEventLoop`的`selector`就是`proactor`，实际传入的就是`IOCP`实例，因此最终就是调用了`IOCP`实例的`select`方法。也是只有在这一步，才会去处理一些IO操作。
​
所以问题来了，针对IO操作，`asyncio`是如何进行调度的呢？我们首先看`IocpProactor.select`的实现：
​

```python
# windows_events.py
class IocpProactor:
    def select(self, timeout=None):
        if not self._results:
            self._poll(timeout)
        tmp = self._results
        self._results = []
        return tmp
    
    def _poll(self, timeout=None):
        if timeout is None:
            ms = INFINITE
        elif timeout < 0:
            raise ValueError("negative timeout")
        else:
            ms = math.ceil(timeout * 1e3)
            if ms >= INFINITE:
                raise ValueError("timeout too big")

        while True:
            status = _overlapped.GetQueuedCompletionStatus(self._iocp, ms)
            if status is None:
                break
            ms = 0

            err, transferred, key, address = status
            try:
                f, ov, obj, callback = self._cache.pop(address)
            except KeyError:
                if self._loop.get_debug():
                    self._loop.call_exception_handler({
                        'message': ('GetQueuedCompletionStatus() returned an '
                                    'unexpected event'),
                        'status': ('err=%s transferred=%s key=%#x address=%#x'
                                   % (err, transferred, key, address)),
                    })
                if key not in (0, _overlapped.INVALID_HANDLE_VALUE):
                    _winapi.CloseHandle(key)
                continue

            if obj in self._stopped_serving:
                f.cancel()
            elif not f.done():
                try:
                    value = callback(transferred, key, ov)
                except OSError as e:
                    f.set_exception(e)
                    self._results.append(f)
                else:
                    f.set_result(value)
                    self._results.append(f)

        # Remove unregistered futures
        for ov in self._unregistered:
            self._cache.pop(ov.address, None)
        self._unregistered.clear()
```

在`IocpProactor._poll`中，会调用`GetQueuedCompletionStatus`去查询完成端口的结果。直到有结果出现，才会根据结果中缓存的`address`数据`pop`出缓存的回调并且执行。

我们通过剖析一个IO操作的例子，来观察其中具体的奥秘：

```python
from multiprocessing import Process
import asyncio
import time


HOST, PORT = '127.0.0.1', 31077


async def _svr_handler(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    data = await reader.read(1024)
    msg = data.decode()
    print(f'[Server] recv: {msg}')

    msg_back = ''.join([msg[i] for i in range(len(msg) - 1, 0, -1)])
    print(f'[Server] send: {msg_back}')
    writer.write(msg_back.encode())
    await writer.drain()

    writer.close()


async def _svr_task():
    svr = await asyncio.start_server(_svr_handler, host=HOST, port=PORT)
    async with svr:
        await svr.serve_forever()


def _svr():
    asyncio.run(_svr_task())


async def _test_cli(msg: str):
    reader, writer = await asyncio.open_connection(HOST, PORT)

    print(f'[Client] send: {msg}')
    writer.write(msg.encode())
    await writer.drain()

    data = await reader.read(1024)
    print(f'[Client] recv: {data.decode()}')

    writer.close()
    await writer.wait_closed()


def test_cli():
    p = Process(target=_svr, daemon=True)
    p.start()
    time.sleep(0.5)
    _msg = 'helloworld'
    asyncio.run(_test_cli(_msg))
    p.kill()


if __name__ == '__main__':
    test_cli()
```

这是一个很简单的`echo server`的实现，`client`发送给`server`信息，`server`返回信息的`reverse`。我们以`client`的写操作`writer.write`为例，看下IO事件是如何在事件循环里被处理的。
​

首先，`open_connection`函数创建了对特定`host`、`port`的连接，并返回连接流的`reader`跟`writer`。
​

```python
async def open_connection(host=None, port=None, *,
                          limit=_DEFAULT_LIMIT, **kwds):
    loop = events.get_running_loop()
    reader = StreamReader(limit=limit, loop=loop)
    protocol = StreamReaderProtocol(reader, loop=loop)
    transport, _ = await loop.create_connection(
        lambda: protocol, host, port, **kwds)
    writer = StreamWriter(transport, protocol, reader, loop)
    return reader, writer
```

针对`reader`，首先会初始化一个`StreamReader`实例，再用`StreamReaderProtocol`对`reader`做进一步的封装。
​

针对`writer`，首先会通过`loop`的`create_connection`方法，针对本次连接创建`transport`实例，相当于一个通信管道的封装。`transport`实例会与先前创建的`StreamReaderProtocol`实例进行绑定。然后，再将创建的`transport`实例和`writer`绑定。
​

在`ProactorEventLoop`中，会这样创建`transport`实例：
​

```python
# proactor_events.py
class BaseProactorEventLoop(base_events.BaseEventLoop):
    return _ProactorSocketTransport(self, sock, protocol, waiter,
                                        extra, server)


class _ProactorSocketTransport(_ProactorReadPipeTransport,
                               _ProactorBaseWritePipeTransport,
                               transports.Transport):

    def __init__(self, loop, sock, protocol, waiter=None,
                 extra=None, server=None):
        super().__init__(loop, sock, protocol, waiter, extra, server)
        base_events._set_nodelay(sock)
```

`_ProactorSocketTransport`实例会同时对`_ProactorReadPipeTransport`以及`_ProactorBaseWritePipeTransport`的初始化，因此会提供对管道读写的功能。其继承链如下：
​

```text
(<class 'asyncio.proactor_events._ProactorSocketTransport'>,
 <class 'asyncio.proactor_events._ProactorReadPipeTransport'>,
 <class 'asyncio.proactor_events._ProactorBaseWritePipeTransport'>,
 <class 'asyncio.proactor_events._ProactorBasePipeTransport'>,
 <class 'asyncio.transports._FlowControlMixin'>,
 <class 'asyncio.transports.Transport'>,
 <class 'asyncio.transports.ReadTransport'>,
 <class 'asyncio.transports.WriteTransport'>,
 <class 'asyncio.transports.BaseTransport'>,
 <class 'object'>)
```

之后，当客户端开始写操作，调用`writer.write`时，实质是进行了以下操作：
​

```python
# proactor_events.py
class _ProactorBaseWritePipeTransport(_ProactorBasePipeTransport,
                                      transports.WriteTransport):
    def write(self, data):
        # 省略一些判断逻辑
        # Observable states:
        # 1. IDLE: _write_fut and _buffer both None
        # 2. WRITING: _write_fut set; _buffer None
        # 3. BACKED UP: _write_fut set; _buffer a bytearray
        # We always copy the data, so the caller can't modify it
        # while we're still waiting for the I/O to happen.
        if self._write_fut is None:  # IDLE -> WRITING
            assert self._buffer is None
            # Pass a copy, except if it's already immutable.
            self._loop_writing(data=bytes(data))
        elif not self._buffer:  # WRITING -> BACKED UP
            # Make a mutable copy which we can extend.
            self._buffer = bytearray(data)
            self._maybe_pause_protocol()
        else:  # BACKED UP
            # Append to buffer (also copies).
            self._buffer.extend(data)
            self._maybe_pause_protocol()
            
    def _loop_writing(self, f=None, data=None):
        try:
            if f is not None and self._write_fut is None and self._closing:
                return
            assert f is self._write_fut
            self._write_fut = None
            self._pending_write = 0
            if f:
                f.result()
            if data is None:
                data = self._buffer
                self._buffer = None
            if not data:
                if self._closing:
                    self._loop.call_soon(self._call_connection_lost, None)
                if self._eof_written:
                    self._sock.shutdown(socket.SHUT_WR)
                self._maybe_resume_protocol()
            else:
                self._write_fut = self._loop._proactor.send(self._sock, data)
                if not self._write_fut.done():
                    assert self._pending_write == 0
                    self._pending_write = len(data)
                    self._write_fut.add_done_callback(self._loop_writing)
                    self._maybe_pause_protocol()
                else:
                    self._write_fut.add_done_callback(self._loop_writing)
            if self._empty_waiter is not None and self._write_fut is None:
                self._empty_waiter.set_result(None)
        except ConnectionResetError as exc:
            self._force_close(exc)
        except OSError as exc:
            self._fatal_error(exc, 'Fatal write error on pipe transport')
```

第一次`write`时，`write_future`以及`buffer`为空，因此触发了`_loop_writing`逻辑。在`_loop_writing`中，调用了`self._loop._proactor.send(self._sock, data)`生成了一个写操作的`future`。而`_proactor`，也就是在`ProactorEventLoop`里的`IocpProactor`实例了。
​

```python
# windows_events.py
class IocpProactor:
    def send(self, conn, buf, flags=0):
        self._register_with_iocp(conn)
        ov = _overlapped.Overlapped(NULL)
        if isinstance(conn, socket.socket):
            ov.WSASend(conn.fileno(), buf, flags)
        else:
            ov.WriteFile(conn.fileno(), buf)

        def finish_send(trans, key, ov):
            try:
                return ov.getresult()
            except OSError as exc:
                if exc.winerror in (_overlapped.ERROR_NETNAME_DELETED,
                                    _overlapped.ERROR_OPERATION_ABORTED):
                    raise ConnectionResetError(*exc.args)
                else:
                    raise

        return self._register(ov, conn, finish_send)
    
    def _register_with_iocp(self, obj):
        if obj not in self._registered:
            self._registered.add(obj)
            _overlapped.CreateIoCompletionPort(obj.fileno(), self._iocp, 0, 0)
            
    def _register(self, ov, obj, callback):
        self._check_closed()

        f = _OverlappedFuture(ov, loop=self._loop)
        if f._source_traceback:
            del f._source_traceback[-1]
        if not ov.pending:
            try:
                value = callback(None, None, ov)
            except OSError as e:
                f.set_exception(e)
            else:
                f.set_result(value)

        self._cache[ov.address] = (f, ov, obj, callback)
        return f
```

在`send`方法中，做了如下操作：
​

- 通过`CreateIoCompletionPort`注册`socket`到完成端口
- 创建一个`Overlapped`实例，通过`WSASend`发送数据到`socket`
- 创建一个关联`Overlapped`实例的`future`，并且判断`Overlapped`实例如果不在`pending`状态就直接执行回调。之后，缓存这个`future`实例到`_cache`中。

​
在先前已经提到，事件循环执行时，`IocpProactor`实例会调用`_poll`方法，其中会采用`GetQueuedCompletionStatus`查询IO操作完成结果。如果发现有IO操作完成，就会从操作中提取`ov.address`并在`_cache`中`pop`出回调然后执行。这样通过`IOCP`模型加上事件循环（事件循环实质就是`IOCP`里头的`worker`），就把`writer.write`的操作从开始到完成的步骤给串起来了。
​
之后就是`await writer.drain`，实质是做了如下操作：

```python
# streams.py
class StreamWriter:
    async def drain(self):
        await self._protocol._drain_helper()
        

class FlowControlMixin(protocols.Protocol):  # 这个会被StreamReaderProtocol继承
    async def _drain_helper(self):
        if self._connection_lost:
            raise ConnectionResetError('Connection lost')
        if not self._paused:
            return
        waiter = self._drain_waiter
        assert waiter is None or waiter.cancelled()
        waiter = self._loop.create_future()
        self._drain_waiter = waiter
        await waiter
```

`writer.drain`实质上是`await`了`StreamReaderProtocol`实例的`_drain_helper`协程，其中做了一些前置检查，然后依据当前事件循环设置了一个`_drain_waiter`的`future`实例，并`await`。为什么要这么做呢？
​
首先，我们可以观察得知，在`_run_once`的逻辑中，如果`_ready`队列有任务，或者是有`_scheduled`里头的定时任务，那么之后`IocpProactor._poll`里头的`GetQueuedCompletionStatus`就会有`timeout`，否则`GetQueuedCompletionStatus`对应的`timeout`就是`INFINITE`，会一直阻塞直到有IO事件完成。有兴趣的同学可以创建一个协程任务，里头`create_future`之后`await`下，一试便知。

然后，回到`_ProactorBaseWritePipeTransport`的`_loop_writing`方法。`_write_fut`被创建后，会直接添加`_loop_writing`为自己的完成回调。当`IocpProactor`实例由`GetQueuedCompletionStatus`获得一个完成事件之后，会取出来执行`ov.getresult()`（在`send`方法的`finish_send`里头）来获取结果，这个结果就会被放到`_write_fut`作为其最终的返回结果。此时`_write_fut`由于完成了，因此会调用自己的回调`_loop_writing`，但这个时候因为`buffer`里没有数据了，所以就会走到`_maybe_resume_protocol`
​

```python
# transports.py
class _FlowControlMixin(Transport):
    def _maybe_resume_protocol(self):
        if (self._protocol_paused and
                self.get_write_buffer_size() <= self._low_water):
            self._protocol_paused = False
            try:
                self._protocol.resume_writing()
            except (SystemExit, KeyboardInterrupt):
                raise
            except BaseException as exc:
                self._loop.call_exception_handler({
                    'message': 'protocol.resume_writing() failed',
                    'exception': exc,
                    'transport': self,
                    'protocol': self._protocol,
                })
                

# streams.py
class FlowControlMixin(protocols.Protocol):
    def resume_writing(self):
        assert self._paused
        self._paused = False
        if self._loop.get_debug():
            logger.debug("%r resumes writing", self)

        waiter = self._drain_waiter
        if waiter is not None:
            self._drain_waiter = None
            if not waiter.done():
                waiter.set_result(None)

```

在`writer.drain`中，我们实际上是一直在`await`这个`_drain_waiter`。在调用`_maybe_resume_protocol`之后，实际是走到了`StreamReaderProtocol`实例的`resume_writing`方法，在`FlowControlMixin`类被定义。这个方法执行了两个操作：
​

- 将`_paused`状态置为`False`
  - `_loop_writing`中，如果数据没发完，就会另外走到`_maybe_pause_protocol`，会把这个状态置为`true`。此时调用`await writer.drain`，就正好会走到了`await _drain_waiter`
- 将`_drain_waiter`设置完成。这样，`await writer.drain`就能完成了

客户端的写操作，在事件循环里就是通过如上复杂的方式调度的。总的来说，是如下的步骤：
​

- 用户调用`writer.write`将数据传进`transport`的写`buffer`
- `transport`的`_loop_writing`发现`buffer`有数据，创建一个写`future`
  - 通过`CreateIoCompletionPort`绑定`socket`跟完成端口
  - 通过`WSASend`发送数据
  - 设置一个回调用来取发送数据的结果
  - 取出来的结果给到写`future`
  - 写`future`预先设置`_loop_writing`为完成回调，得到结果后执行下一轮`_loop_writing`
- 用户调用`await writer.drain`
  - 写`future`在创建后，发现写`future`没有到完成状态，先调用`_maybe_pause_protocol`设置`protocol`的`_paused`为`True`
  - 在`writer.drain`里判断`protocol`为`_paused`，重置`_drain_waiter`为新的实例并`await`
  - 写操作完成，触发写`future`的回调`_loop_writing`。下一轮`_loop_writing`发现没有数据发送，调用`_maybe_resume_protocol`，设置`protocol`的`_paused`为`False`，并设置`_drain_waiter`为完成
  - `_drain_waiter`完成，退出`await writer.drain`

针对读操作，以及其它的IO操作，有兴趣的小伙伴可以深入研究^_^
