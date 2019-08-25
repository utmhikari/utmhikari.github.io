---
title: 【Easy Python】第六话：解锁三头六臂——Python多进程并行
date: 2019/05/11 19:47:50
categories:
- Easy Python
tags:
- python
- GIL
- 并行
- 并发
- 多进程
---

## 前言

前段时间，我和我的领导回到了母校，和我的师父师母聚餐。聚餐点了很多东西，大碗宽面，牛肉炒饭，韩国烤肉，吃都吃不完。虽然我的领导最近长得比以前p了些，但是吃饭速度还是慢悠悠。唉，要是我的领导能有个三头六臂，每个手都夹菜，每个头都去啃，那吃饭速度可就蹭蹭地涨上去了啊！

人无法三头六臂，但在Python里，我们可以做到。

## 并发&并行实验

要想实现三头六臂的效率，不走单一顺序流，我们不仅需要让多个任务能够并发（Concurrent），还能够并行（Parallel）运作。

假使吃饭吃到一半，人有三急，摘花回来继续用膳，那么如果把“吃饭”与“解手”当作两个任务，那么它们便是便是并发运作，但不并行。如果太追求效率，蹲坑恰饭，那便即是并发，也是并行了。

在Python中，我们可以用三种方式实现并发。但是并不是所有的方法，都支持并行。

这三种方法是：

<!-- more -->

- 多线程 Multi Threading
- 多进程 Multi Processing
- 异步IO Async IO

其中，异步IO的实现方法，我们在第四章[《玩转豆瓣二百五：下》](https://utmhikari.github.io/2019/03/31/easypython/iv)中已经介绍过。多线程和多进程的实现方法，可以参考[Python官方文档](https://docs.python.org/zh-cn/3/)，或者干脆直接看下面的实例。

通过一个简单的运行时间测试我们就可以发现，这三种方法中，哪些方法是能够真正利用并行的效率：

```python
from multiprocessing import Pool
from threading import Thread
import datetime
import functools
import asyncio

TOTAL = 20000  # 子任务执行次数


def task(n):  # 每个子任务，从n减到-n
    end = -n
    while n > end:
        n -= 1


def sequential():  # 一般的顺序执行
    for i in range(TOTAL):
        task(i)


def multi_process():  # 多进程，设定最大进程数为10，放到一个池里调度
    pool = Pool(10)
    pool.map(task, range(TOTAL))


async def async_io():  # 异步IO，详见Easy Python第四章
    async def async_task(n):
        task(n)
    await asyncio.gather(*[async_task(i) for i in range(TOTAL)])


def multi_thread():  # 多线程，设定10个线程，每个线程执行2000个task
    def tasks(ns):
        for n in ns:
            task(n)
    threads = []
    inputs = [[] for _ in range(10)]
    for i in range(TOTAL):
        inputs[(i % 10)].append(i)
    for i in range(10):
        threads.append(Thread(target=functools.partial(tasks, inputs[i])))
        threads[-1].start()
    for thread in threads:
        thread.join()


if __name__ == '__main__':
    # sequential
    start = datetime.datetime.now()
    sequential()
    print("Sequential: %s" % (datetime.datetime.now() - start).total_seconds())
    # multi-process
    start = datetime.datetime.now()
    multi_process()
    print("Multi-Process: %s" % (datetime.datetime.now() - start).total_seconds())
    # asyncio
    start = datetime.datetime.now()
    asyncio.run(async_io())
    print("Async-IO: %s" % (datetime.datetime.now() - start).total_seconds())
    # multi-thread
    start = datetime.datetime.now()
    multi_thread()
    print("Multi-Thread: %s" % (datetime.datetime.now() - start).total_seconds())
```

结果出炉！

```text
Sequential: 18.116519
Multi-Process: 3.879628
Async-IO: 18.225281
Multi-Thread: 18.119936
```

我们发现，只有采用多进程的方式，能够符合我们的并行猜测。其它方式，甚至比顺序执行还要慢一些，应当不是并行运行。

## 为什么是多进程？

### 线程与进程

首先，我们简要介绍一下[线程](https://en.wikipedia.org/wiki/Thread_%28computing%29)与[进程](https://en.wikipedia.org/wiki/Process_%28computing%29)。

- 线程（Thread）：操作系统调度最小单位，顺序执行的程序流
- 进程（Process）：计算机程序的实例，线程的容器

进程，好比是一个特定工作的流程，是相对宏观的；线程，则是一个个子任务的流程，是相对微观的。一个进程中，可以容纳多个不同的线程以执行不同类型的工作。同一个进程的不同线程之间，共享了许多当前进程信息，相互独立性较弱；而同一个操作系统的进程之间，共享信息较少，相互独立性强。

在实际执行程序的时候，对于单个（核）CPU而言，同一时刻只能跑一个特定的线程。CPU通过不停地切换不同线程实现各个线程任务的并发，并且由于CPU手速太快，造成了我们一按`ctrl + alt + del`所看到的，同一时刻几十个进程都在同时跑的假象。但是，对于多核CPU而言，我们就可以做到在多个CPU上，并发并且并行多个线程，增加执行效率。但即便如此，Python的多线程，却无法做到这一点。

### 全局解释器锁GIL

Python多线程无法利用多核CPU的优势，其罪魁祸首，在于全局解释器锁（GIL，Global Interpreter Lock）

了解GIL，可以看这个资料：[UnderstandingGIL](http://www.dabeaz.com/python/UnderstandingGIL.pdf)

运行Python代码，需要通过解释器（Intepreter）进行。Python解释器在读取了一行Python代码后，就会将其执行，执行完后，再读取下一行代码，以此类推。

GIL能够使得同一时刻，只有一个线程能在执行。Python的官方实现Cython就采用了这种机制，保证Python进程中资源的状态能够同步（synchronize）到各个线程中。可以看到，GIL简单粗暴，让我们省去了资源同步的担忧，但相对地，造成了一种同一时刻一个线程包场的景象，不能满足细粒度的资源同步操作。

因此，解决这个问题的办法就是开启多个进程，让每一个进程都有自己的解释器跟GIL。这样，就能实现多任务的并行了。

## 多进程资源共享——TornadoCenter

进程之间的资源信息通常是不共享的，因此要借由系统自身的机制。比如说内存信息共享，在Python的多进程模块`multiprocessing`中，就提供了`Pipe（管道）`、`Queue（队列）`等方式，使得不同进程之间的数据可以共享。

在我的[TornadoCenter](https://github.com/utmhikari/TornadoCenter)小项目中，就有这样的一个实例——主进程是cmd小黑框命令行程序，通过规定的指令可以开启服务器进程与客户端进程。客户端进程通过网络读写往服务器进程发送数据，而服务器进程则通过`Queue`队列发送数据给主进程。Tornado是一个著名的Python网络框架，因此能满足这方面的需求。

主进程大概设计如下：

```python
def __init__(self):
    """
    忽略其它初始化
    """
    self._cmd_state = {
        'exit': self._exit,
        'help': self._help,
        'server': {
            'start': self._start_server,
            'stop': self._stop_server,
            'params': self._show_server_params,
            'status': self._show_server_status
        },
        'client': {
            'start': self._start_client,
            'stop': self._stop_client,
            'status': self._show_client_status
        }
    }
    self._server_holder = TornadoTCPServerHolder()
    self._client_holder = TornadoTCPClientHolder()

def _dispatch(self, cmds, cmd_state):
    """
    dispatch cmds on cmd state machine
    :param cmds: cmd.split(' ')
    :param cmd_state: the current state of cmd
    :return:
    """
    len_cmd = len(cmds)
    if len_cmd == 0 or cmds[0] not in cmd_state.keys():
        return False
    state = cmd_state[cmds[0]]
    if callable(state):
        sig = signature(state)
        len_pars = len(sig.parameters)
        if len_pars == 0:
            return state() if len_cmd == 1 else False
        else:
            return functools.partial(state, cmds[1:])() if len_cmd > 1 else state()
    else:
        return self._dispatch(cmds[1:], state) if len_cmd > 1 else False


def loop(self):
    """
    Main loop of TornadoCenter
    :return:
    """
    self._log('Start main loop!!!')
    while True:
        cmd = input('\n$ ').strip()
        if len(cmd) == 0:
            continue
        cmds = cmd.split(' ')
        if not self._dispatch(cmds, self._cmd_state):
            self._exception('Invalid command: %s!' % cmd)
            self._help()
```

我们来拆解一下业务：

- 初始化变量
  - cmd_state: 根据指令查找对应执行函数的reference
  - server_holder: 管理服务器进程
  - client_holder: 管理客户端进程
- 函数
  - loop：主循环，使得我们在cmd界面上能一直输入指令，输错了则显示帮助
  - dispatch: 根据指令与cmd_state，查找&执行对应函数

对于管理服务器进程的`server_holder`，我们需要让其持有服务器进程的实例`process`，互通服务器进程数据的通道`queue`，以及查询服务器进程状态的一些接口。

```python
class TornadoTCPServerHolder(BaseCSHolder):
    """
    Tornado TCPServer Holder
    """
    def __init__(self):
        """
        Initialization
        """
        BaseCSHolder.__init__(self, 'TCPServerHolder')
        '''
        Server Info
        '''
        self._process = None
        self._queue = Queue()
        self._params = {
            'host': '127.0.0.1',
            'port': 5000,
            'num_processes': 1
        }
        '''
        Monitor Thread
        '''
        self._monitor = None
        self._is_monitor_stop = False

    def _monitor_loop(self):
        """
        Monitor thread, print the data received by the server
        """
        self._log('Starting Monitor...')
        while True:
            if self._is_monitor_stop:
                self._is_monitor_stop = False
                break
            while not self._queue.empty():
                data = self._queue.get()
                try:
                    if data.startswith('JSON|'):
                        json_data = json.loads(data[5:])
                        self._log('Received JSON data: %s\n%s' % (
                            type(json_data), json.dumps(json_data, indent=2)
                        ))
                    else:
                        self._log('Received String: %s' % data)
                except Exception as e:
                    self._exception(e)
            time.sleep(1)

    def start(self):
        """
        Start Tornado TCPServer Process
        :return:
        """
        self._log('Starting Tornado TCPServer...')
        if self.is_server_active():
            self._exception('Cannot start server! The TCPServer is still active!')
            return False
        else:
            self._process = TornadoTCPServerProcess(queue=self._queue, params=self._params)
            self._process.start()
            self._monitor = Thread(target=self._monitor_loop)
            self._monitor.start()
            return True
```

物以类聚，我们可以将服务器进程的管理抽象到一个类中。这个类继承了另外一个叫`BaseCSHolder`的类，具备打印日志以及编辑参数的功能。

```python
class BaseCSHolder(Logger):
    """
    Client and Server Holder Class
    """
    def __init__(self, tag='BaseCSHolder'):
        Logger.__init__(self, tag)
        self._params = dict()

    def get_param_keys(self):
        """
        get the keys of params
        :return: sorted param keys
        """
        return sorted(self._params.keys())

    def get_params(self):
        """
        get the params
        :return: params dict
        """
        return self._params

    def set_params(self, params):
        """
        set the params of the server
        """
        pass  # 此处省略
```

总的来看，在启动服务器进程之后，同时也起一个线程执行`monitor_loop`的逻辑，监控`Queue`里的数据。每当`Queue`里有数据的时候，就取出来数据，打印出来。

对于服务器进程的实例（Server Process Instance），我们可以让其持有服务器实例（Server Instance）、主线程传递的信息（比如服务器参数与`Queue`）以及其它自身信息。服务器进程实例相当于是服务器实例的容器。

```python
class TornadoTCPServerProcess(Process, Logger):
    """
    TCPServer Process
    """
    def __init__(self, queue=None, params=None):
        Process.__init__(self, daemon=True)
        Logger.__init__(self, 'TCPServerProcess')
        self._queue = queue
        self._params = params
        self._server = None  # 运行该进程（run）后，会开启服务器实例
```

而最后，对于服务器实例，就是实实在在地继承服务器框架了。

Tornado框架的用法，可以参考[官方文档](http://www.tornadoweb.org/en/stable/guide.html)

```python
class TornadoTCPServer(TCPServer, Logger):
    """
    TCPServer instance of tornado
    """
    def __init__(self, queue=None):
        TCPServer.__init__(self)
        Logger.__init__(self, 'TCPServer')
        self._queue = queue

    async def handle_stream(self, stream, address):
        host, port = address
        addr = '%s:%s' % (host, port)
        self._log('Handling stream at %s' % addr)
        proto_cnt = 0
        await stream.write('Welcome to tornado server!'.encode('utf-8'))
        while True:
            try:
                data = await stream.read_bytes(4096, partial=True)
                decode_data = data.decode().strip()
                self._queue.put(decode_data)
                proto_cnt += 1
                if proto_cnt % 10 == 0:
                    self._log('Received %d protos from %s!' % (proto_cnt, addr))
            except StreamClosedError:
                self._log('Stream at %s:%s is closed!' % (host, port))
                break
```

可以看到，每次服务器实例在收到数据后，就会把数据解码放到`Queue`队列头里。这样在主线程那一端，就可以实时在队列尾取出数据打印了。

这样，我们就实现了多进程之间的资源共享。怎么样，要不要试试“千手观音”~

## 总结

有了多进程与异步的支持，Python在基础任务调度上，更是增强了一个层次

Easy Python第六章——多进程并行，也标志着Easy Python系列进入尾声

第七章，会对Easy Python系列做最终的整理

See ya~
