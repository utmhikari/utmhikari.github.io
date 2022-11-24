---
title: 【Python随笔】python进程池ProcessPoolExecutor的用法与实现分析
date: 2021/06/08 21:58:51
categories:
- Python随笔
tags:
- python
- 并发
- ProcessPoolExecutor
- multiprocessing
- 进程池
---

在python开发期间，由于GIL的原因，不能直接采用并行的方式处理代码逻辑。在multiprocessing库的支持下，python程序能够启动子进程执行特定的任务，但子进程的管理也成为了问题。为了简化用户开发成本，python在concurrent.futures下内置了ProcessPoolExecutor这一数据结构，实现了简单的进程管理及任务调度。如果没有特别的需求，开发者只需要用ProcessPoolExecutor即可实现并行执行任务。因此，本文简单对ProcessPoolExecutor的实现进行分析，帮助大家更加了解python开发中进程/任务调度的一种方式。

首先来看ProcessPoolExecutor的用法，可以参考[官方文档](https://docs.python.org/3/library/concurrent.futures.html)

- constructor：构造器
  - max_workers：最大worker数量
  - context：进程启动方式，比如spawn、fork等。可以参考[这篇文章](https://stackoverflow.com/questions/43818519/what-is-the-meaning-of-context-argument-in-multiprocessing-pool-pool/43818829)
  - initializer：初始化环境用的回调/钩子，会在传进去的任务执行之前调用（比如要import什么库，读取什么配置之类）
  - initargs：初始化回调的参数
- submit：提交特定任务，返回一个future实例（类似于js的promise）
- map：批量submit
- shutdown：关闭进程池并销毁资源

可以看到用法非常简单，用户一侧只需要这样操作即可得到任务执行结果：

<!-- more -->

```python
from concurrent.futures import ProcessPoolExecutor

def task(sleep_sec=10, tag='test'):
    print('[%s] start sleep' % tag)
    time.sleep(sleep_sec)
    print('[%s] finish sleep' % tag)
    return 100


def main():
    process_pool = ProcessPoolExecutor(max_workers=3)
    future = process_pool.submit(task, 3, tag='TEST')
    ret = future.result()
    print('result is %s' % str(ret))
    process_pool.shutdown()


if __name__ == '__main__':
    main()
```

然后就可以打印出以下内容：

```text
[TEST] start sleep
[TEST] finish sleep 
result is 100
```

其中，finish sleep在start sleep打印的3秒后才打印出来

简单的入口后面肯定存在精巧的逻辑。在ProcessExecutorPool源码中，有很清晰的注释去阐述这一数据结构的实现，有兴趣的读者可以直接翻越源码，debug源码来探索其中的逻辑

ProcessPoolExecutor的基础结构如下：

![python_processpoolexecutor](/uploads/geekdaily/python_processpoolexecutor/ProcessPoolExecutor.png)

其中，Queue Management Thread（队列管理线程）是整个ProcessPoolExecutor的核心，不仅控制任务的收发，而且调度任务在不同进程中的执行，并且处理因为各种原因带来的进程池的异常。

以上面代码为例，ProcessPoolExecutorl整个执行流程，可以如下所示：

- 用户初始化ProcessPoolExecutor
  - 检查worker数量合法性，设置进程启动方式context
  - 初始化WorkID队列、WorkID->WorkItem的缓存map、调用队列Call Queue、结果队列Result Queue
  - 初始化用来激活队列管理线程的pipe
    - 队列管理线程会对一系列fd/pipe进行管理。pipe包括激活队列管理线程的以及结果队列的；fd则是进程池每个进程的
    - 队列管理线程会select这些fd/pipe，根据对应事件作出行为
- 用户submit任务（函数+参数）到ProcessPoolExecutor实例
  - 自增WorkID，将任务所需的函数&参数放到WorkItem，然后把这些信息缓存到到WorkID->WorkItem的map里
  - 若是未启动进程池，先启动进程池。然后启动队列管理线程
  - 唤醒队列管理线程工作
    - 唤醒的方式：给主线程连到激活队列管理线程的pipe发二进制空字符串，会被select到
  - 切到队列管理线程，线程内主循环先拿到WorkID&WorkItem，同时侦测到被唤醒的signal，于是开始执行正常任务
    - 把WorkID跟WorkItem结合为CallItem放到Call Queue里
    - 进程池每个进程会从Call Queue提取任务执行，将结果ResultItem放到Result Queue。如果进程异常，会直接把pid放到Result Queue
    - 队列管理线程有个is_broken变量控制是否整个进程池/队列坏了，如果坏了就不能正常执行任务，整个executor都得被销毁
  - 队列管理线程select到Result Queue并读取其中内容。提取出运行结果后，和缓存的WorkID&WorkItem对上。这样用户侧用future.result()就可以得到结果
- 用户销毁ProcessPoolExecutor
  - 将关闭队列管理线程的flag置为true
  - 队列管理线程在主循环中发现flag置为true，默认会等待所有WorkItem执行完后执行销毁操作
  - 发送None给到进程池所有进程，这些进程收到None会返回pid，队列管理线程发现pid会自动除掉相应进程索引记录，并等待进程join
  - 关闭Call Queue，赋值Result Queue为None
  - 进程与Call Queue全部关闭后，队列管理线程跳出主循环，主线程等待队列管理线程join
  - 关闭激活队列管理线程的pipe
