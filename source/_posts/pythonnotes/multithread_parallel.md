---
title: 【Python随笔】python多线程什么情况下可以并行？什么情况下不能？
date: 2022/07/03 00:32:34
categories:
- Python随笔
tags:
- python
- 多线程
- 并行
- GIL
- 并发
---

在`python`面试里，多线程是避不开的话题，其中一个经典问题就是，多线程`threading.Thread`是不是并行运行。这个问题的答案，说是也不对，说不是也不对，得分情况讨论。本文就带领大家，分析并回答这个问题。

我们用一段代码来做实验：

<!-- more -->

```python
import subprocess
from threading import Thread, Lock
import datetime
import time


_lock = Lock()


def log(*args, **kwargs):
    with _lock:
        print(*args, **kwargs)


def _io_task():
    # 单个task执行约3s
    subprocess.run(['ping', '127.0.0.1'], capture_output=True)


def _code_task():
    # 单个task执行约0.8s
    tms = 0
    while tms < 50000000:
        tms += 1


def testfunc(num):
    st = datetime.datetime.now()
    # _io_task()
    _code_task()
    et = datetime.datetime.now()
    dt = et - st
    log(f'{num} -> {dt.total_seconds() * 1000}ms')


def main():
    num_threads = 5
    threads = []
    st = datetime.datetime.now()
    for i in range(num_threads):
        t = Thread(target=testfunc, args=(i,))
        threads.append(t)
    for t in threads:
        t.start()
    time.sleep(0)
    for t in threads:
        t.join()
    et = datetime.datetime.now()
    dt = et - st
    log(f'overall {dt.total_seconds() * 1000}ms')


if __name__ == '__main__':
    main()
```

这段代码意思很容易懂，起了5个`testfunc`为`target`的线程，然后主线程等待这些线程全部执行结束`join`，最后统计每个线程的开始结束时间间隔和开始结束时间间隔。

执行了之后我们会发现如果`test_func`里设置的是`code_task`的话，那么总时间相当于一个线程执行时间的`num_threads`倍，这个可以通过设置`num_threads`为1以及更高的数字来实验到，而更为蹊跷的是，每个线程执行的时间间隔和总的执行时间间隔几乎相差无几。可以看下面的输出例子：

```text
# num_threads = 1
0 -> 873.087ms
overall 874.0830000000001ms

# num_threads = 5
0 -> 4278.944ms
1 -> 4412.494ms
2 -> 4488.241ms
4 -> 4243.062ms
3 -> 4882.43ms
overall 5156.513ms
```

然后，如果`test_func`里设置的是`io_task`的话，`num_threads`就算设置三五个，用的时间基本都一样：

```text
# num_threads = 3
0 -> 3061.7909999999997ms
2 -> 3061.7909999999997ms
1 -> 3061.7909999999997ms
overall 3062.788ms

# num_threads = 5
2 -> 3036.288ms
4 -> 3035.291ms
1 -> 3036.288ms
0 -> 3549.756ms
3 -> 3549.756ms
overall 3549.756ms
```

所以两种情况下，一个是节省时间并行的，一个是没节省时间不并行的。这是为什么呢？

很多同学会提到`GIL`这个概念，没错，`GIL`就是关键。`GIL`是全局解释器锁，它的意义就在于，单个`python`运行时环境里，同一时刻，保证只有一个操作系统线程能够解释执行`python`代码。`python`多线程，实质是起了多个操作系统线程，竞争`GIL`锁解释执行`python`代码，在多线程执行`code_task`的情况下，不同线程需要获取`GIL`，才能执行`while`、`+=`之类的语句，所以这些线程全部执行完的话，总的时间是累加的。而在`io_task`的情况下，等待`ping`命令返回的期间是阻塞在操作系统的`io`接口，并不需要解释执行`python`代码，因此单个任务线程不需要每时每刻都拥有`GIL`，各个线程间也没有什么竞争关系了，所以最后呈现了并行的状态。这就是上述问题的答案了。

当然，这个问题还有引申的空间——为什么`code_task`的场景下，每个线程执行的时间间隔和总的执行时间间隔几乎相差无几，而不是线程一个接一个串行执行完毕呢？这是因为在`python`运行时环境里`GIL`的竞争是时分复用的，每个时间间隔`sys.getswitchinterval()`都会触发一次`GIL`的释放和竞争，这样呈现的结果就是一个线程执行一点字节码，之后另一个线程抢到机会也执行一点字节码，循环往复，直到所有线程执行结束。所以这种机制下，多线程之间是并发的，最终结束的时刻，不会相差太多时间。

`python`多线程的机制，如果要深入了解，可以参考笔者以前在`Medium Python`系列写的[这篇文章](https://utmhikari.top/2021/10/30/mediumpython/iii/)，里面已经清楚讲述了`python`线程启动的逻辑以及`GIL`竞争的逻辑。
