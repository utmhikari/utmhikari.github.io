---
title: 【从零单排Golang】第十六话：channel的用法和基本原则
date: 2024/04/13 19:15:40
categories:
- 从零单排Golang
tags:
- Golang
- channel
- 并发
- 多线程
- 后端开发
---

在基于Golang的后端开发中，channel是一个必须要掌握的并发编程概念。和python的queue一样，channel在不同的goroutine里承担着传递信息的作用，使得业务逻辑的状态上下文可以在不同的goroutine中共享。今天，我们就来看一下channel的用法还有一些使用上的基本原则。

首先，我们需要知道什么场景下会用到channel。一个简单的例子是，在主流程里，我们希望启动一个方便处理panic的goroutine，异步跑一个任务，然后主流程等待这个goroutine给join进来。解决这个问题，就可以用到channel，代码这样写：

<!-- more -->

```go
func TestAsyncTask(t *testing.T) {
    joiner := make(chan struct{})

    log.Printf("[main] start async task...")
    go func() {
        defer func() {
            if r := recover(); r != nil {
                log.Printf("[goroutine] panic: %v", r)
            }
            close(joiner)
        }()

        log.Printf("[goroutine] start async task...")
        time.Sleep(5 * time.Second) // task logic
        log.Printf("[goroutine] end async task!")
    }()

    log.Printf("[main] wait for join...")
    <-joiner
    log.Printf("[main] async task joined!")
}
```

我们定义一个channel，发起异步任务，并在主流程阻塞地去接收这个channel的事件。在异步任务执行完成后，把channel给close掉，这样主流程可以接收到channel给close掉的事件，就能继续后面的逻辑。这样，就达到了任务线程join的效果。

在上述的场景下，我们用到的channel相对于消息发送方是阻塞的，如果发送方给这个channel发送一条消息，而接收方的逻辑还没有跑到的话，那么发送方就会一直阻塞在发送逻辑。假使我们需要实现一个类dispatcher（多consumer）的调度模型，不断地去根据消息内容把消息分发到不同consumer-worker上，那么采用对于发送方阻塞的channel的话，就有可能因为dispatcher在处理过程中产生瓶颈，造成发送方等待超时。在这种情况下，我们就需要用到非阻塞的channel，也就是在定义channel时，也去声明这个channel的buffer大小，这样我们就可以有足够的缓冲区去缓存消息，解决发送方的无限等待问题。

```go
// channel chan instance
var channel chan int

// bufSize for non-blocking channel
const bufSize = 1024

func initBlockingChannel() {
    channel = make(chan int)
}

func initNonBlockingChannel() {
    channel = make(chan int, bufSize)
}

func exampleProduceMsg() {
    msg := 1
    select {
    case channel <- msg:
        log.Printf("sent msg: %v", msg)
    default:
        log.Printf("send msg failed!")
    }
}
```

而消费一个channel，我们可以构建一个loop，来循环处理channel发送过来的内容。比如一个dispatcher，就需要一个for循环，不断拿消息，把消息发给下游的任务handler：

```go
func launchConsumer(c <-chan int) {
    numMsgs := 0
    defer func() {
        log.Printf("[Consumer] overall received %d msgs!", numMsgs)
    }()
    for { // 其它写法：for msg := range c
        select {
        case msg, ok := <-c:
            if ok { // 收到了消息
                log.Printf("[Consumer] received msg: %v", msg)
                numMsgs++
            } else { // channel closed
                log.Printf("[Consumer] channel closed!")
                return
            }
        }
    }
}
```

channel使用的基本原则是，从producer端去close掉channel。produce端触发close后，consumer端就能够知道channel被close掉，进而结束掉自己的chunk。而如果是consumer端主动close，producer端在不知情的情况下，往channel发送消息，就会panic。

因此，为了规避这个风险，一是要从producer去关channel，而是不论是怎样的生产消费模型，都需要保证channel仅被close一次。简单来讲，close掉channel的操作，放到producer最外层函数的defer里面，就能解决问题。

对于单个producer的模拟，我们可以简单做一个for循环，去不断发送消息。中途打断的方式采用可cancel的context，当循环过程中检测到context被cancel掉，就停止发送消息。整个代码如下：

```go
func launchSingleProducer(c chan<- int) {
    defer func() {
        log.Printf("[SingleProducer] close channel...")
        close(channel)
    }()
    numMsgs := 10
    for i := 0; i < numMsgs; i++ {
        log.Printf("[SingleProducer] start send msg: %v", i)
        select {
        case c <- i:
            log.Printf("[SingleProducer] finish send msg: %v", i)
            time.Sleep(1 * time.Second)
        case <-ctx.Done():
            log.Printf("[SingleProducer] context done!")
            return
        default:
            log.Printf("[SingleProducer] send msg failed...")
            time.Sleep(1 * time.Second)
        }
    }
}
```

golang中ctx的上下文信息，也可以在不同的goroutine中共享，可以参考[这篇文章](https://utmhikari.top/2023/04/01/gofromzero/10_context/)对于context模块的介绍。在单个producer场景下，每次循环，我们可以select不同的信道，看当刻是可以给channel发送一条消息，还是收到了ctx上下文结束的事件。如果上下文结束掉，就终止整个producer。close操作，放到defer里执行即可。

consumer端处理多个channel的发送/接收事件，我们可以通过循环+select的通用模版去实现。每轮循环，就select单个channel的单个事件来处理，代码写起来也简洁明了。

对于多个producer的模拟，我们可以创建一个waitGroup去管理多个producer的进度，可以参考[这篇文章](https://utmhikari.top/2023/08/06/gofromzero/13_waitgroup/)来了解waitGroup的用法。与此同时，每个producer的行为则是在for循环里发消息，直到消息发完或者context结束掉，才结束单个producer的进度。在主goroutine中，只需要wait这个waitGroup，然后在defer中close掉channel即可。代码如下：

```go
func launchMultiProducers(c chan<- int) {
    defer func() {
        log.Printf("[SingleProducer] close channel...")
        close(channel)
    }()

    produce := func(id int, numMsgs int) {
        for i := 0; i < numMsgs; i++ {
            msg := id*10000 + i
            log.Printf("[MultiProducers] [%d] start send msg: %v", id, msg)
            select {
            case c <- i:
                log.Printf("[MultiProducers] [%d] finish send msg: %v", id, msg)
                time.Sleep(1 * time.Second)
            case <-ctx.Done():
                log.Printf("[MultiProducers] [%d] context done, break!", id)
                return
            default:
                log.Printf("[SingleProducer] send msg failed...")
                time.Sleep(1 * time.Second)
            }
        }
        log.Printf("[MultiProducers] [%d] finish send all msgs!", id)
    }

    numIDs := 10
    numMsgsEach := 10
    waitGroup := sync.WaitGroup{}

    log.Printf("[MultiProducers] launch producers...")
    for x := 1; x <= numIDs; x++ {
        waitGroup.Add(1)
        id := x
        go func() {
            defer waitGroup.Done()
            produce(id, numMsgsEach)
        }()
    }

    waitGroup.Wait()
    log.Printf("[MultiProducers] finish all producers!")
}
```
