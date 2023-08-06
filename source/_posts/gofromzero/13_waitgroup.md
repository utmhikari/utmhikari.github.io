---
title: 【从零单排Golang】第十三话：使用WaitGroup等待多路并行的异步任务
date: 2023/08/06 21:01:02
categories:
- 从零单排Golang
tags:
- Golang
- WaitGroup
- 并行
- 异步
- 后端开发
---

在后端开发当中，经常会遇到这样的场景：请求给了批量的输入，对于每一个输入，我们都要给外部发请求等待返回，然后才能继续其它自己的业务逻辑。在这样的case下，如果每一个输入串行处理的话，那么很大一部分时间都会损耗在给外部发请求这个环节，因此我们会希望把这些请求放到各个goroutine里异步执行，等待批量执行完成之后再继续后面的逻辑。这个时候，我们就可以用到这个东西：sync.WaitGroup

WaitGroup提供了增减计数以及阻塞等待计数归零的线程安全接口。当主goroutine增加计数并等待的时候，子goroutine的逻辑中若引用了一个WaitGroup实例的话，也可以在结束（defer）的时候去减少计数，这样当主goroutine自旋等待计数归零时，等待的逻辑就返回了，就继续后面的内容。整体上，就达到了等待多路并行的异步任务这一效果。

一个典型的代码案例如下：

<!-- more -->

```go
func TestWaitGroup(t *testing.T) {
    var wg sync.WaitGroup

    startTime := time.Now()
    for i := 0; i < 5; i++ {
        n := i + 1
        sleepTime := time.Duration(n) * time.Second
        wg.Add(1)

        go func() {
            defer wg.Done()

            t.Logf("task %d started", n)
            time.Sleep(sleepTime)
            t.Logf("task %d ended", n)
        }()
    }
    t.Logf("waiting for all tasks done...")
    wg.Wait()
    endTime := time.Now()
    t.Logf("all tasks done! elapsed time: %v", endTime.Sub(startTime))
}
```

整个逻辑很简单，我们起了5个任务，每个任务分别sleep上1到5秒。主goroutine此时在每个任务开始前，给WaitGroup实例wg加上1个计数，而在子goroutine里，defer地调用wg.Done减少计数。主goroutine起完任务之后，直接调用wg.Wait自选等待。这样5s后等所有任务Done，主goroutine就会接下来打印消耗时间的日志信息了。

打印的内容如下：

```text
=== RUN   TestWaitGroup
    wg_test.go:26: waiting for all tasks done...
    wg_test.go:21: task 5 started
    wg_test.go:21: task 1 started
    wg_test.go:21: task 2 started
    wg_test.go:21: task 3 started
    wg_test.go:21: task 4 started
    wg_test.go:23: task 1 ended
    wg_test.go:23: task 2 ended
    wg_test.go:23: task 3 ended
    wg_test.go:23: task 4 ended
    wg_test.go:23: task 5 ended
    wg_test.go:29: all tasks done! elapsed time: 5.0015089s
--- PASS: TestWaitGroup (5.00s)
PASS
```

WaitGroup的用法非常简单，但这里注意的是，实际遇到这种编程场景，一般会涉及到多任务运行结果收集还有程序异常处理相关的内容。因此，像recover或者select超时等一些子goroutine任务异常处理的逻辑，可能视实际情况都得配合加上。
