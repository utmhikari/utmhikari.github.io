---
title: 【Hard Python】【第二章-异步IO】1、asyncio事件循环的创建
date: 2022/02/12 20:24:45
categories:
- Hard Python
tags:
- python
- asyncio
- 事件循环
- proactor
- iocp
---

python3中增加的重要特性之一即为`asyncio`，其提供了异步编程的原语支持，从而能够让python在事件驱动、协程协同等方面的编程场景大杀四方。

事件循环`EventLoop`是异步编程中的核心概念之一。python的异步IO，就从事件循环的实现开始讲起。

首先看一段示例代码：

```python
async def _test_run_main():
    for i in range(3):
        await asyncio.sleep(1)
        print(f'[test_run] {i}')


def test_run():
    coro = _test_run_main()
    asyncio.run(coro)
```

通过`async def`定义的函数，其返回值是一个异步协程`coroutine`。协程相当于是事件循环里的一个单位任务，通过`asyncio.run`接口就可以将其运行起来。因此我们先来看`asyncio.run`的实现：

<!-- more -->

```python
def run(main, *, debug=None):
    if events._get_running_loop() is not None:
        raise RuntimeError(
            "asyncio.run() cannot be called from a running event loop")
    if not coroutines.iscoroutine(main):
        raise ValueError("a coroutine was expected, got {!r}".format(main))

    loop = events.new_event_loop()
    try:
        events.set_event_loop(loop)
        if debug is not None:
            loop.set_debug(debug)
        return loop.run_until_complete(main)
    finally:
        try:
            _cancel_all_tasks(loop)
            loop.run_until_complete(loop.shutdown_asyncgens())
            loop.run_until_complete(loop.shutdown_default_executor())
        finally:
            events.set_event_loop(None)
            loop.close()
```

在`asyncio.run`中，首先会检查协程合法性以及当前线程是否有已在跑的事件循环，之后会新启动一个事件循环，并设置为当前线程在跑的事件循环，最后等待协程完成。完成后，会关闭事件循环，并取消当前线程事件循环的设置。

事件循环的诞生，便是从`new_event_loop`方法开始了。以windows为例，我们来看下当创建一个新的事件循环时，会发生哪些调用：

```python
# runners.py
def new_event_loop():
    return get_event_loop_policy().new_event_loop()


# events.py
def _init_event_loop_policy():
    global _event_loop_policy
    with _lock:
        if _event_loop_policy is None:  # pragma: no branch
            from . import DefaultEventLoopPolicy
            _event_loop_policy = DefaultEventLoopPolicy()


def get_event_loop_policy():
    """Get the current event loop policy."""
    if _event_loop_policy is None:
        _init_event_loop_policy()
    return _event_loop_policy


# windows_events.py
class WindowsProactorEventLoopPolicy(events.BaseDefaultEventLoopPolicy):
    _loop_factory = ProactorEventLoop
    
    
DefaultEventLoopPolicy = WindowsProactorEventLoopPolicy


# events.py
class BaseDefaultEventLoopPolicy(AbstractEventLoopPolicy):
    def new_event_loop(self):
        return self._loop_factory()
    

# windows_events.py
class ProactorEventLoop(proactor_events.BaseProactorEventLoop):
    def __init__(self, proactor=None):
        if proactor is None:
            proactor = IocpProactor()
        super().__init__(proactor)
```

事件循环创建的策略有多种，在调用`new_event_loop`时，实质是执行默认事件循环策略的创建方法。以windows为例，默认策略是`ProactorEventLoop`。

`proactor`模型本身为异步IO而生，其基本工作原理如下：

- 用户态应用预先设定一组针对不同IO操作完成事件的回调（`Handler`），同时向内核注册一个完成事件的`dispatcher`（也就是`proactor`）
- 用户态线程发起异步IO操作后会即刻返回结果
- IO操作在内核执行完成后会通知`proactor`，`proactor`根据完成事件的类型，触发对应的完成事件回调

在windows下`ProactorEventLoop`实际是使用了`IOCP`模型，中文翻译叫IO完成端口，其基本工作原理如下：

- 通过`CreateIoCompletionPort`创建完成端口
  - 完成端口，实质是一个用于缓存IO完成事件的队列
- 创建一组`worker thread`关联完成端口
- 创建`listen server`
- `listen server`在`accept`到客户端连接后，创建`PerHandleData`实例，将客户端`socket`与`PerHandleData`实例与完成端口关联起来。执行上述的关联后，可以通过`WSARecv`发起接收客户端数据的异步IO操作，然后继续`accept`
- 在`worker thread`中，通过`GetQueueCompletionStatus`方法获取IO操作的完成结果。如`WSARecv`完成后，可以直接提取接收到的客户端数据，执行对应的操作
- `listen server`退出，通过`PostQueuedCompletionStatus`向完成端口发送特殊的数据包，用以让`worker thread`退出

了解了`proactor`和`iocp`的基本工作原理后，我们就可以看python版`ProactorEventLoop`的具体实现了。

```python
# windows_events.py
class IocpProactor:
    def __init__(self, concurrency=0xffffffff):
        self._loop = None
        self._results = []
        self._iocp = _overlapped.CreateIoCompletionPort(
            _overlapped.INVALID_HANDLE_VALUE, NULL, 0, concurrency)
        self._cache = {}
        self._registered = weakref.WeakSet()
        self._unregistered = []
        self._stopped_serving = weakref.WeakSet()
        
 
class ProactorEventLoop(proactor_events.BaseProactorEventLoop):
    def __init__(self, proactor=None):
        if proactor is None:
            proactor = IocpProactor()
        super().__init__(proactor)
        
        
# proactor_events.py
class BaseProactorEventLoop(base_events.BaseEventLoop):
    def __init__(self, proactor):
        super().__init__()
        logger.debug('Using proactor: %s', proactor.__class__.__name__)
        self._proactor = proactor
        self._selector = proactor   # convenient alias
        self._self_reading_future = None
        self._accept_futures = {}   # socket file descriptor => Future
        proactor.set_loop(self)
        self._make_self_pipe()
        if threading.current_thread() is threading.main_thread():
            # wakeup fd can only be installed to a file descriptor from the main thread
            signal.set_wakeup_fd(self._csock.fileno())
            
    def _make_self_pipe(self):
        # A self-socket, really. :-)
        self._ssock, self._csock = socket.socketpair()
        self._ssock.setblocking(False)
        self._csock.setblocking(False)
        self._internal_fds += 1
        

# base_events.py
class BaseEventLoop(events.AbstractEventLoop):

    def __init__(self):
        self._timer_cancelled_count = 0
        self._closed = False
        self._stopping = False
        self._ready = collections.deque()
        self._scheduled = []
        self._default_executor = None
        self._internal_fds = 0
        # Identifier of the thread running the event loop, or None if the
        # event loop is not running
        self._thread_id = None
        self._clock_resolution = time.get_clock_info('monotonic').resolution
        self._exception_handler = None
        self.set_debug(coroutines._is_debug_mode())
        # In debug mode, if the execution of a callback or a step of a task
        # exceed this duration in seconds, the slow callback/task is logged.
        self.slow_callback_duration = 0.1
        self._current_handle = None
        self._task_factory = None
        self._coroutine_origin_tracking_enabled = False
        self._coroutine_origin_tracking_saved_depth = None

        # A weak set of all asynchronous generators that are
        # being iterated by the loop.
        self._asyncgens = weakref.WeakSet()
        # Set to True when `loop.shutdown_asyncgens` is called.
        self._asyncgens_shutdown_called = False
        # Set to True when `loop.shutdown_default_executor` is called.
        self._executor_shutdown_called = False
```

当`ProactorEventLoop`实例初始化时，会先创建`IocpProactor`实例，里面通过`CreateIoCompletionPort`创建了一个完成端口。之后再调用`BaseProactorEventLoop`的初始化函数。`BaseProactorEventLoop`先初始化`BaseEventLoop`，然后设置`proactor`，并创建了一组`socketpair`。

这样，事件循环的实例就被创建出来了。
