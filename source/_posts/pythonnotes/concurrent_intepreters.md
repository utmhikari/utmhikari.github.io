---
title: 【Python随笔】通过多解释器并行提升python并发效率
date: 2026/08/01 09:55:14
categories:
- Python随笔
tags:
- python
- multiprocessing
- 并发
- 并行
- InterpreterPoolExecutor
---

在非常久远的文章中，我们提到python中实现并行执行程序的方式主要是通过[multiprocessing](https://utmhikari.top/2021/06/08/pythonnotes/python_processpoolexecutor/)实现的，而并非多线程（Threading）。机理层面，大致是会开一个新的子进程独立执行，主进程维护一个Sentinel（fd），默认通过pickle跟pipe方式和子进程通信。

而现在，python也到了3.14版本，除了multiprocessing与Threading之外，对于多解释器的支持也比较完善。多解释器的机理可以参考[concurrent.interpreters官方文档](https://docs.python.org/zh-cn/3/library/concurrent.interpreters.html)，简单来讲就是这类并发不像多线程受GIL的约束，一个进程里执行多套解释器，每个解释器有自己的GIL，有点类似于Golang的机制。以下是一些典型用法：

<!-- more -->

首先是interpreter本身，其支持的行为和thread跟process都比较类似，通信的话也可以用queue来通信。整体也比较容易理解。

```python
def example_queue_communication():
    queue = interpreters.create_queue()
    interp = interpreters.create()

    def worker(q):
        for i in range(5):
            q.put(i * i)

    t = interp.call_in_thread(worker, queue)
    t.join()

    results = []
    for _ in range(5):
        results.append(queue.get())
    print(f"Received from sub-interpreter: {results}")

    interp.close()
    print()
```

因为3.14出了InterpreterPoolExecutor，所以我们也可以更加方便去map一些并行任务。比如拿InterpreterPoolExecutor跟ThreadPoolExecutor对比：

```python
def example_executor_vs_thread():

    def cpu_work(n):
        total = 0
        for i in range(n):
            total += i * i
        return total

    work_size = 5_000_000
    num_tasks = 4

    # InterpreterPoolExecutor (真正并行)
    start = time.perf_counter()
    with InterpreterPoolExecutor(max_workers=num_tasks) as executor:
        list(executor.map(cpu_work, [work_size] * num_tasks))
    interp_time = time.perf_counter() - start

    # ThreadPoolExecutor (受 GIL 限制)
    start = time.perf_counter()
    with ThreadPoolExecutor(max_workers=num_tasks) as executor:
        list(executor.map(cpu_work, [work_size] * num_tasks))
    thread_time = time.perf_counter() - start

    # 串行基准
    start = time.perf_counter()
    for _ in range(num_tasks):
        cpu_work(work_size)
    serial_time = time.perf_counter() - start

    print(f"  串行:              {serial_time:.4f}s")
    print(f"  ThreadPool:        {thread_time:.4f}s (加速比 {serial_time / thread_time:.2f}x)")
    print(f"  InterpreterPool:   {interp_time:.4f}s (加速比 {serial_time / interp_time:.2f}x)")
    print()
```

打印出来结果预期是：

```text
  串行:              0.5426s
  ThreadPool:        0.5073s (加速比 1.07x)
  InterpreterPool:   0.1932s (加速比 2.81x)
```

当然多解释器的使用也是有限制的，比如下面这一段就执行不了：

```python
def example_executor_as_completed():

    def slow_square(n):
        time.sleep(0.1 * (5 - n))  # 模拟不同耗时
        return n * n

    with InterpreterPoolExecutor(max_workers=4) as executor:
        future_to_n = {executor.submit(slow_square, n): n for n in range(1, 6)}

        for future in as_completed(future_to_n):
            n = future_to_n[future]
            print(f"  n={n} 完成, 结果={future.result()}")
    print()
```

原因是slow_square定义域在example_executor_as_completed里面，是个方法级local的对象，没法直接分享给另一个解释器，如果多线程在一个解释器里是通的，多进程新起整个Runtime也是通的。这里目前的解法是把slow_square提到global层面，才可以解决。

所以整体看下来，多解释器并行也不是万能的，使用方面还是有很多限制，我们需要充分理解其行为之后，才去投入使用。如果是面对cpu密集场景，不涉及C层自己扩展模块的话，完全可以用多解释器这套机制提升性能，不需要用multiprocessing，如果涉及C层自己扩展模块的话，得保证自己模块的健壮性，否则会把整个进程搞崩。
