---
title: 【Hard Python】【第一章-多进程】3、Pool，多任务并行进程池
date: 2022/01/30 16:36:44
categories:
- Hard Python
tags:
- python
- multiprocessing
- pool
- 进程池
- 并行
---

前面讲了进程创建与进程通信的内容，接下来讲一下多进程编程最能发挥的地方。对于同时运行多个同质任务来讲，采用`multiprocessing.Pool`进程池去管理是最方便的。`Pool`的用法如下：

```python
from multiprocessing import Pool, process
import os
import pprint


def _test_func(a, b):
    result = a + b
    print(f'{os.getpid()}: {result}')
    return result


def test_pool():
    test_data = [(2 * i, 2 * i + 1) for i in range(16)]
    with Pool(4) as p:
        pprint.pprint(process.active_children())
        results = p.starmap(_test_func, test_data)  # starmap指iterable的unpack，*args这样，详情看源码注释
        print(f'{os.getpid()}: {results}')  # 得到_test_func的所有结果


if __name__ == '__main__':
    test_pool()

```

打印出来的结果，可能是这样子的：

<!-- more -->

```text
[<SpawnProcess name='SpawnPoolWorker-4' pid=7648 parent=2468 started daemon>,
 <SpawnProcess name='SpawnPoolWorker-3' pid=15812 parent=2468 started daemon>,
 <SpawnProcess name='SpawnPoolWorker-1' pid=3496 parent=2468 started daemon>,
 <SpawnProcess name='SpawnPoolWorker-2' pid=3120 parent=2468 started daemon>]
3496: 1
3496: 5
3496: 9
3496: 13
3496: 17
3496: 21
3496: 25
3496: 29
3496: 33
3496: 37
3496: 41
3496: 45
3496: 49
3496: 53
3496: 57
3496: 61
2468: [1, 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61]
```

我们可以在结果中看到这样的景象：

- 当进入`with Pool`代码段时，进程池中的进程已经被预先创建了
- 总共16个任务，最后却只在进程池里单独1个进程中运行（小概率在2个进程中运行）

具体缘由，我们一起来看`Pool`的代码实现。

```python
class Pool(object):
    def __init__(self, processes=None, initializer=None, initargs=(),
                 maxtasksperchild=None, context=None):
        # 忽略一些初始变量设置
        
        # processes
        self._processes = processes
        try:
            self._repopulate_pool()
        except Exception:
            for p in self._pool:
                if p.exitcode is None:
                    p.terminate()
            for p in self._pool:
                p.join()
            raise

        sentinels = self._get_sentinels()
        
        # worker handler
        self._worker_handler = threading.Thread(
            target=Pool._handle_workers,
            args=(self._cache, self._taskqueue, self._ctx, self.Process,
                  self._processes, self._pool, self._inqueue, self._outqueue,
                  self._initializer, self._initargs, self._maxtasksperchild,
                  self._wrap_exception, sentinels, self._change_notifier)
            )
        self._worker_handler.daemon = True
        self._worker_handler._state = RUN
        self._worker_handler.start()

        # task handler
        self._task_handler = threading.Thread(
            target=Pool._handle_tasks,
            args=(self._taskqueue, self._quick_put, self._outqueue,
                  self._pool, self._cache)
            )
        self._task_handler.daemon = True
        self._task_handler._state = RUN
        self._task_handler.start()
        
        # result handler
        self._result_handler = threading.Thread(
            target=Pool._handle_results,
            args=(self._outqueue, self._quick_get, self._cache)
            )
        self._result_handler.daemon = True
        self._result_handler._state = RUN
        self._result_handler.start()

```

一个`Pool`实例总共包含以下的内容：

- `self._processes`：所有worker子进程实例
- `self._worker_handler`：管理worker子进程的线程
- `self._task_handler`：任务调度线程
- `self._result_handler`：结果收集线程

上述所有的`worker`子进程跟管理线程在初始化的时候，都会被启动。首先我们来看`worker`进程的情况：

```python
def _repopulate_pool(self):
    return self._repopulate_pool_static(self._ctx, self.Process,
                                        self._processes,
                                        self._pool, self._inqueue,
                                        self._outqueue, self._initializer,
                                        self._initargs,
                                        self._maxtasksperchild,
                                        self._wrap_exception)

@staticmethod
def _repopulate_pool_static(ctx, Process, processes, pool, inqueue,
                            outqueue, initializer, initargs,
                            maxtasksperchild, wrap_exception):
    """Bring the number of pool processes up to the specified number,
    for use after reaping workers which have exited.
    """
    for i in range(processes - len(pool)):
        w = Process(ctx, target=worker,
                    args=(inqueue, outqueue,
                          initializer,
                          initargs, maxtasksperchild,
                          wrap_exception))
        w.name = w.name.replace('Process', 'PoolWorker')
        w.daemon = True
        w.start()
        pool.append(w)
        util.debug('added worker')
        
def worker(inqueue, outqueue, initializer=None, initargs=(), maxtasks=None,
           wrap_exception=False):
    if (maxtasks is not None) and not (isinstance(maxtasks, int)
                                       and maxtasks >= 1):
        raise AssertionError("Maxtasks {!r} is not valid".format(maxtasks))
    put = outqueue.put
    get = inqueue.get
    if hasattr(inqueue, '_writer'):
        inqueue._writer.close()
        outqueue._reader.close()

    if initializer is not None:
        initializer(*initargs)

    completed = 0
    while maxtasks is None or (maxtasks and completed < maxtasks):
        try:
            task = get()
        except (EOFError, OSError):
            util.debug('worker got EOFError or OSError -- exiting')
            break

        if task is None:
            util.debug('worker got sentinel -- exiting')
            break

        job, i, func, args, kwds = task
        try:
            result = (True, func(*args, **kwds))
        except Exception as e:
            if wrap_exception and func is not _helper_reraises_exception:
                e = ExceptionWithTraceback(e, e.__traceback__)
            result = (False, e)
        try:
            put((job, i, result))
        except Exception as e:
            wrapped = MaybeEncodingError(e, result[1])
            util.debug("Possible encoding error while sending result: %s" % (
                wrapped))
            put((job, i, (False, wrapped)))

        task = job = result = func = args = kwds = None
        completed += 1
    util.debug('worker exiting after %d tasks' % completed)
```

`_repopulate_pool`是启动所有`worker`进程的出发点，顺流而下，所有`worker`进程最终会执行`worker`函数。`worker`函数有如下的步骤：

- 执行`initializer(*initargs)`。在多进程的场景下，有很多模块到了子进程可能是未初始化的状态，而`initializer`就提供了一个在子进程中初始化某些模块或者变量的途径。
- 从`inqueue`中`get`一个`task`的实例，将其`unpack`
- 执行`task`中的`func`，得到结果
- 将结果`put`到`outqueue`

然后我们再看下`_task_handler`，对应的函数是`Pool._handle_tasks`

```python
@staticmethod
def _handle_tasks(taskqueue, put, outqueue, pool, cache):
    thread = threading.current_thread()

    for taskseq, set_length in iter(taskqueue.get, None):
        task = None
        try:
            # iterating taskseq cannot fail
            for task in taskseq:
                if thread._state != RUN:
                    util.debug('task handler found thread._state != RUN')
                    break
                try:
                    put(task)
                except Exception as e:
                    job, idx = task[:2]
                    try:
                        cache[job]._set(idx, (False, e))
                    except KeyError:
                        pass
            else:
                if set_length:
                    util.debug('doing set_length()')
                    idx = task[1] if task else -1
                    set_length(idx + 1)
                continue
            break
        finally:
            task = taskseq = job = None
    else:
        util.debug('task handler got sentinel')

    try:
        # tell result handler to finish when cache is empty
        util.debug('task handler sending sentinel to result handler')
        outqueue.put(None)

        # tell workers there is no more work
        util.debug('task handler sending sentinel to workers')
        for p in pool:
            put(None)
    except OSError:
        util.debug('task handler got OSError when sending sentinels')

    util.debug('task handler exiting')
```

`task_handler`负责从`taskqueue`中得到`task`实例，并`put`到`inqueue`中。当所有`task`实例推送完毕后，像`result_handler`和所有`worker process`推送了`None`实例。从先前`worker`的代码中可以知晓，当`inqueue`收到了`None`，就代表任务已经推送完毕，可以`break`退出了。而至于为何也给到`result_handler`一个`None`实例，我们就看下`result_handler`的代码，来分析其中具体的机制。

```python
@staticmethod
def _handle_results(outqueue, get, cache):
    thread = threading.current_thread()

    while 1:
        try:
            task = get()
        except (OSError, EOFError):
            util.debug('result handler got EOFError/OSError -- exiting')
            return

        if thread._state != RUN:
            assert thread._state == TERMINATE, "Thread not in TERMINATE"
            util.debug('result handler found thread._state=TERMINATE')
            break

        if task is None:
            util.debug('result handler got sentinel')
            break

        job, i, obj = task
        try:
            cache[job]._set(i, obj)
        except KeyError:
            pass
        task = job = obj = None

    while cache and thread._state != TERMINATE:
        try:
            task = get()
        except (OSError, EOFError):
            util.debug('result handler got EOFError/OSError -- exiting')
            return

        if task is None:
            util.debug('result handler ignoring extra sentinel')
            continue
        job, i, obj = task
        try:
            cache[job]._set(i, obj)
        except KeyError:
            pass
        task = job = obj = None

    if hasattr(outqueue, '_reader'):
        util.debug('ensuring that outqueue is not full')
        # If we don't make room available in outqueue then
        # attempts to add the sentinel (None) to outqueue may
        # block.  There is guaranteed to be no more than 2 sentinels.
        try:
            for i in range(10):
                if not outqueue._reader.poll():
                    break
                get()
        except (OSError, EOFError):
            pass

    util.debug('result handler exiting: len(cache)=%s, thread._state=%s',
          len(cache), thread._state)
```

在`handle_results`的主循环中，会不断地从`outqueue`里`get`结果，然后放到`cache`中。参考`worker`进程的实现中我们可以知晓，从`outqueue`里获取的结果即是`worker`任务执行后的返回值。

当所有`task`在`handle_tasks`线程被消费完之后，`handle_tasks`线程会在`outqueue`里`put`一个`None`值。`handle_results`线程接收到`None`值后，直到`cache`为空或者`Pool`被终止（TERMINATE）为止，都会继续接收子进程任务执行结果并存到`cache`里。`cache`为空或者`Pool`被终止之后，`handle_results`线程会清空`outqueue`，然后退出。

从`worker`、`task`、`result`线程的作用可以看到，`inqueue`、`outqueue`、`cache`是连接用户业务线程和子进程之间的桥梁。`inqueue`和`outqueue`的作用在前面的叙述中已经非常清楚，一个用来上传任务，一个用来下发执行结果。因此最终，我们还是要深入研究一下`cache`的运行机制。

首先我们还是回顾一开始给的例子，`test_pool`函数：

```python
def test_pool():
    test_data = [(2 * i, 2 * i + 1) for i in range(16)]
    with Pool(4) as p:
        pprint.pprint(process.active_children())
        results = p.starmap(_test_func, test_data)  # starmap指iterable的unpack，*args这样，详情看源码注释
        print(f'{os.getpid()}: {results}')  # 得到_test_func的所有结果
```

`test_pool`函数调用了`starmap`，`starmap`方法需要给定一个任务函数以及一组参数，和`map`不同的是，`starmap`指代的参数是带星的（`*args`），因此在调用任务函数时会`unpack`对应的参数。

`starmap`之后，涉及到的方法定义如下：

```python
def starmapstar(args):
    return list(itertools.starmap(args[0], args[1]))

def starmap(self, func, iterable, chunksize=None):
    '''
    Like `map()` method but the elements of the `iterable` are expected to
    be iterables as well and will be unpacked as arguments. Hence
    `func` and (a, b) becomes func(a, b).
    '''
    return self._map_async(func, iterable, starmapstar, chunksize).get()

@staticmethod
def _get_tasks(func, it, size):
    it = iter(it)
    while 1:
        x = tuple(itertools.islice(it, size))
        if not x:
            return
        yield (func, x)

def _guarded_task_generation(self, result_job, func, iterable):
    '''Provides a generator of tasks for imap and imap_unordered with
    appropriate handling for iterables which throw exceptions during
    iteration.'''
    try:
        i = -1
        for i, x in enumerate(iterable):
            yield (result_job, i, func, (x,), {})
    except Exception as e:
        yield (result_job, i+1, _helper_reraises_exception, (e,), {})

def _map_async(self, func, iterable, mapper, chunksize=None, callback=None,
        error_callback=None):
    '''
    Helper function to implement map, starmap and their async counterparts.
    '''
    self._check_running()
    if not hasattr(iterable, '__len__'):
        iterable = list(iterable)

    if chunksize is None:
        chunksize, extra = divmod(len(iterable), len(self._pool) * 4)
        if extra:
            chunksize += 1
    if len(iterable) == 0:
        chunksize = 0

    task_batches = Pool._get_tasks(func, iterable, chunksize)
    result = MapResult(self, chunksize, len(iterable), callback,
                       error_callback=error_callback)
    self._taskqueue.put(
        (
            self._guarded_task_generation(result._job,
                                          mapper,
                                          task_batches),
            None
        )
    )
    return result
```

各类`map/map_async`方法，最终都会落实到`_map_async`方法。在`_map_async`方法中会做以下几件事情：

- 计算`chunksize`，即每`batch`子任务的数量
- 通过`_get_tasks`函数，获取传递子任务`batch`的`generator`
- 生成`MapResult`实例`result`
- 在`taskqueue`中放入`_guarded_task_generation`的任务`generator`实例

每个子进程最终会调用`mapper(task_batch)`，相当于是`list(itertools.starmap(func, task_batch))`，也就是单个子进程会执行一个`batch`的任务，然后返回一组这个`batch`的执行结果。

从这个角度推论，假设每个任务函数执行要1s，总共16个子任务，`chunksize`是14，`pool`的`size`是2，那么一执行起来，前2秒的话2个子进程都会打印执行结果，然后接下来12秒就只有第1个子进程打印结果了。这是因为，第1个子进程一批被分了14个，第2个子进程一批就被分了剩下2个。如果其它变量不变，`pool`的`size`是3，那么打印的效果也和`size`为2的时候一样，这是因为`chunksize`太大，前2个子进程已经瓜分了所有子任务（14、2），第3个子进程啥任务都分不到了。

所以`chunksize`的设定，也是一门学问。实际使用`pool`的时候要注意这个坑。

接下来注意力转到`MapResult`实例`result`上，也是在这个地方会对任务缓存`cache`做一些操作。首先我们看`MapResult`的定义：

```python
job_counter = itertools.count()

class ApplyResult(object):
    def __init__(self, pool, callback, error_callback):
        self._pool = pool
        self._event = threading.Event()
        self._job = next(job_counter)
        self._cache = pool._cache
        self._callback = callback
        self._error_callback = error_callback
        self._cache[self._job] = self

    def ready(self):
        return self._event.is_set()

    def successful(self):
        if not self.ready():
            raise ValueError("{0!r} not ready".format(self))
        return self._success

    def wait(self, timeout=None):
        self._event.wait(timeout)

    def get(self, timeout=None):
        self.wait(timeout)
        if not self.ready():
            raise TimeoutError
        if self._success:
            return self._value
        else:
            raise self._value
        
        
class MapResult(ApplyResult):
    def __init__(self, pool, chunksize, length, callback, error_callback):
        ApplyResult.__init__(self, pool, callback,
                             error_callback=error_callback)
        self._success = True
        self._value = [None] * length
        self._chunksize = chunksize
        if chunksize <= 0:
            self._number_left = 0
            self._event.set()
            del self._cache[self._job]
        else:
            self._number_left = length//chunksize + bool(length % chunksize)

    def _set(self, i, success_result):
        self._number_left -= 1
        success, result = success_result
        if success and self._success:
            self._value[i*self._chunksize:(i+1)*self._chunksize] = result
            if self._number_left == 0:
                if self._callback:
                    self._callback(self._value)
                del self._cache[self._job]
                self._event.set()
                self._pool = None
        else:
            if not success and self._success:
                # only store first exception
                self._success = False
                self._value = result
            if self._number_left == 0:
                # only consider the result ready once all jobs are done
                if self._error_callback:
                    self._error_callback(self._value)
                del self._cache[self._job]
                self._event.set()
                self._pool = None
```

针对`starmap`而言，在`worker`中，执行了一批子任务之后，会调用`put((job, i, result))`返回独立的`job_id`、任务组编号、子任务批次的结果集。我们需要注意到，在`result`初始化时侯，会通过`[None] * length`占位所有的结果（`self._values`），并且在缓存中设置本次`job`（`ApplyResult`中`self._cache[self._job] = self`），然后在`handle_results`线程中`_set`结果时，调用了`MapResult._set`，会根据任务组编号`i`把对应位置的结果替代。直到所有批次的结果集执行结果返回后，最终会清楚缓存中的这次`starmap`的`job_id`，然后调用`self._event.set()`

`starmap`函数会阻塞，直到所有结果返回。实现阻塞操作的方式，即是用了`threading.Event()`。`starmap`返回的是`result.get()`，在`get`的实现里，会调用`self._event.wait`，也就是阻塞，直到`self._event.set`。这样，只有所有结果返回，`starmap`才会返回。如果大家日常开发中，有这种等待直到执行成功的业务需求，不妨尝试用`threading.Event()`，比`sleep`轮询的方式优雅的多。

说到底，`Pool`为多进程编程提供了灵活的任务调度模型。日常如果需要用到进程池做并行操作，用原生的`multiprocessing.Pool`就是不二选择。

当然，并行任务还有一种选择方案实用`ProcessPoolExecutor`，比原生的`Pool`稍微轻量级一点。`ProcessPoolExecutor`的机理实现，也可以参考[这篇文档](https://blog.csdn.net/u013842501/article/details/117717200)。
