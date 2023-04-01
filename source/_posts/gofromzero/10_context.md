---
title: 【从零单排Golang】第十话：快速理解并上手context的基础用法
date: 2023/04/01 17:11:46
categories:
- 从零单排Golang
tags:
- Golang
- context
- WithCancel
- WithDeadline
- WithValue
---

在`Golang`的各种用法当中，`context`可谓是最能够体现`Golang`语言特性的模块之一。`context`的本意为`情境、上下文`，而在`Golang`程序当中，则可以被用于描述一次`调用`、`会话`或者`任务`的状态信息。关于`context`网上有很多语法以及源码分析的文档，但是里面很多却不能从实战场景体现`context`的作用，导致这个概念难以理解。因此这一回，经由踩坑`context`后，笔者将结合自己的理解，给大家讲述`context`在`Golang`怎么用来最为方便，怎么理解最为实用。

首先来了解一下什么是`context`。我们先走源码：

```go
type Context interface {
    Deadline() (deadline time.Time, ok bool)
    Done() <-chan struct{}
    Err() error
    Value(key any) any
}
```

在源码定义中可以看到，`context`模块给开发者定义了一个接口约定`Context`。在先前[关于接口的文章](https://utmhikari.top/2023/02/18/gofromzero/08_cache_interface/)中有提到，接口本身定义的是一个实体可以做的行为，那么我们初步理解`context`的时候，就可以通过`Context`的定义，知道一个`Context`可以干什么。

假设一个`Context`实例`ctx`，关联到了一次`会话`，作为当次`会话`的`情境`。根据代码定义，`Context`可以做以下几种行为：

<!-- more -->

- `Deadline` -> 透出两个信息：本次`会话`的DDL是否有设置（`ok`），设置到了什么时候（`deadline`）
- `Done` -> 通过调用`<- ctx.Done()`，可以阻塞等待本次`会话`的`情境`结束
- `Err` -> 当`情境`结束时，可以知道本次`会话`结束掉`情境`的原因
  - 这个原因是程序性质的，比如`超时`或者`程序主动调用cancel`，不具备业务性质
  - 要给到具备业务性质的`情境`结束原因，需要用到`context.Cause`，具体用法见下文
- `Value` -> 透出当前`情境`设定的某一个`字段`的值

可以看到，`Context`实例具备共享值信息（`Value`、`Deadline`）以及共享状态信息（`Done`、`Err`）的作用，定义上非常轻量实用。在实战场景里，`context`也有两个最为典型的应用场景，分别是：

- 单次会话里，在相互配合的`goroutine`之间，共享当次会话的值、状态等情境信息
- 长链路调用里，透传调用信息，覆盖到整个调用链路，使得每单个调用链路信息都可回溯

这两种应用场景，通过`context`模块的预置功能，加以组合，就可以充分实现。

在`Golang`的设计里，每一个`context.Context`实例生成，都必须关联到一个父级的`Context`实例，这样的设计下，比如父级的情境结束了，那么子级的情境也会递归结束，从而能够满足情境之间的关联关系。`Golang`为开发者提供了两个最根部的`Context`实例：`context.Background()`和`context.TODO()`，均是单纯实现了`Context`接口定义，返回零值。在状态层面，这两个`Context`不可结束，因为没有等待结束的`chan`在`Done`接口里实现。

业务如果要自己定义`Context`实例，就必须继承这两个`Context`实例，或者他们的子`Context`实例。这两个根部`Context`的业务含义是：

- `context.Background()`：业务层面需要起一个最根部的`Context`实例，继承这个
- `context.TODO()`：业务还不清楚继承什么`Context`时，继承这个

上一段代码案例：

```go
func TestCtxBase(t *testing.T) {
    ctxBg := context.Background()
    ctxTodo := context.TODO()
    t.Logf("context.Background: %s, %d", ctxBg, ctxBg)
    t.Logf("context.TODO: %s, %d", ctxBg, ctxTodo)
    select {
    case <-ctxTodo.Done():
        t.Logf("context.TODO is done")
    case <-time.After(1 * time.Second):
        t.Logf("timeout")
    }
}
```

由于`context.Background()`和`context.TODO()`不可取消，显然地，这段代码会1秒之后打印`timeout`。

接下来就来看一下，`context`怎么在不同`goroutine`之间共享会话情境信息。`Golang`默认定义了`context.WithCancel`、`context.WithCancelCause`、`context.WithDeadline`以及`context.WithValue`等几个`Context`实例构造器，构造出来的内容里，除了新创建的`Context`实例之外，也会给一些回调函数，用来修改新`Context`实例的状态信息。

首先来看`context.WithCancel`和`context.WithCancelCause`，两者作用相似：

- `context.WithCancel(parent Context) (ctx Context, cancel CancelFunc)`
  - 输入：父`Context`
  - 输出：新`Context`、用于结束掉新`Context`的回调，签名为`func()`
- `context.WithCancelCause(parent Context) (ctx Context, cancel CancelFunc)`
  - 输入：父`Context`
  - 输出：新`Context`、用于结束掉新`Context`的回调，签名为`func(cause error)`

`context.WithCancelCause`相对于`context.WithCancel`，唯一的不同点是可以输入一个`cause`信息，来声明是因为什么业务性质的原因从而取消整个`Context`，而程序写法上大致相似。

假设我们针对一次会话，建立起这样的`goroutine`协作模式：

- 主`goroutine`决定某个会话要不要继续做下去
- 子`goroutine`处理业务逻辑，但期间还要关注主`goroutine`的决策，来决定继不继续做

那么从程序角度，就可以写这么一个例子：

```go
func TestCtxWithCancel(t *testing.T) {
    cancelCause := errors.New("debug")
    ctxCancel, cancel := context.WithCancelCause(context.Background())
    t.Logf("context.WithCancel: %v, %p -> cause: %v", ctxCancel, cancel, cancelCause)

    sleepTimeout := 1 * time.Second  // 主goroutine觉得这个工作该完成的用时
    waiterTimeout := 2 * time.Second  // 子goroutine觉得这个工作该完成的用时

    // 子goroutine
    join := make(chan string)
    go func(ctx context.Context, timeout time.Duration, retChan chan string) {
        var ret string
        select {
        case <-ctx.Done():  // 主goroutine都不干了，那就摆烂吧，返回done
            t.Logf("ctx done! -> err: %v, cause: %v", ctx.Err(), context.Cause(ctx))
            ret = "done"
        case <-time.After(waiterTimeout):  // 返回timeout
            t.Logf("waiter timeout")
            ret = "timeout"
        }
        retChan <- ret
    }(ctxCancel, waiterTimeout, join)

    // 主goroutine再等待sleepTimeout就不干了
    time.Sleep(sleepTimeout)
    cancel(cancelCause)
    t.Logf("cancel done!")

    // join waiter
    ret := <-join
    t.Logf("waiter ret: %s", ret)
}
```

这种场景下，如果`sleepTimeout`小于`waiterTimeout`，由于主`goroutine`先调用`cancel`，那么子`goroutine`的`select`里就会先监听到`ctx.Done`，从而直接返回一个`done`字符串结束掉。反之如果`sleepTimeout`大于`waiterTimeout`，子`goroutine`会等到`waiterTimeout`之后，再返回一个`timeout`字符串。但不管怎么说，`ctxCancel`实例在主`goroutine`和子`goroutine`之间是有效共享的，主`goroutine`通过`cancel`方法操作`ctxCancel`实例的结果，子`goroutine`是可以感知到的。

接下来看一下`context.WithDeadline`，和`context.WithCancel`一样，也是返回新的`Context`实例和主动结束情境的`cancel`函数。但有所不同的是，业务需要输入一个自动结束掉情境的`deadline`时刻，这样到了`deadline`的时候，新的`Context`实例会自动地`cancel`掉整个情境。有兴趣的同学，可以看下`context.WithDeadline`怎么通过源码实现的，本文不做源码解析，只看用法。

假设和刚才一样，对于一次业务会话的协作关系，主`goroutine`决定做不做，子`goroutine`做牛马，那么如果用到`context.WithDeadline`的话，可以这样描述：

```go
func TestCtxWithDeadline(t *testing.T) {
    timeout := 3 * time.Second

    deadline := time.Now().Add(timeout)
    ctxDeadline, cancel := context.WithDeadline(context.Background(), deadline)
    t.Logf("context.WithDeadline: %v, %p", ctxDeadline, cancel)

    // deadline/cancel detector
    join := make(chan string)
    go func(ctx context.Context, retChan chan string) {
        var ret string
        select {
        case <-ctx.Done():
            ddl, ok := ctx.Deadline()
            if !ok {
                t.Logf("ctx deadline not set")
                ret = "nothing"
            } else if time.Now().After(ddl) {
                t.Logf("ctx reached deadline: %v -> err: %v", ddl, ctx.Err())
                ret = "deadline"
            } else {
                t.Logf("ctx early canceled! -> err: %v", ctx.Err())
                ret = "cancel"
            }
        }
        retChan <- ret
    }(ctxDeadline, join)

    // manually cancel after cancelTimeout
    cancelTimeout := 1 * time.Second
    time.Sleep(cancelTimeout)
    cancel()
    t.Logf("cancel done!")

    ret := <-join
    t.Logf("ret: %s", ret)
}
```

当子`goroutine`有监听到整个情境结束时，就有几种可能性：

- 情境没有设置`deadline`，因为其它原因被结束掉
- 情境设置了`deadline`，并且到了`deadline`时间
- 情境设置了`deadline`，但还没到`deadline`时间就被其它原因取消掉了

那么业务层面，就可以根据这几种可能性，来分配不同的业务逻辑了。

最后，我们来看`context.WithValue`的作用。`context.WithValue`，本质是为继承的`Context`实例，新增一对`key`和`value`的映射。用法非常简单：

```go
func TestCtxWithValue(t *testing.T) {
    key1, value1 := "hello", "world"
    ctxValue1 := context.WithValue(context.Background(), key1, value1)
    key2, value2 := "foo", "bar"
    ctxValue2 := context.WithValue(ctxValue1, key2, value2)

    t.Logf("ctxValue1: %s", ctxValue1)
    t.Logf("ctxValue1.%s = %v", key1, ctxValue1.Value(key1))  // world
    t.Logf("ctxValue1.%s = %v", key2, ctxValue1.Value(key2))  // nil
    t.Logf("ctxValue2: %s", ctxValue2)
    t.Logf("ctxValue2.%s = %v", key1, ctxValue2.Value(key1))  // world
    t.Logf("ctxValue2.%s = %v", key2, ctxValue2.Value(key2))  // bar
}
```

在长链路调用的场景下，RPC/日志框架层面，可以约定一组携带调用信息的`keys`。以此为基准，RPC框架在收到请求时，可以创建一次调用的`Context`，通过`context.WithValue`为这些`keys`赋值，然后再把包含调用信息的`Context`实例给到业务`handler`。业务`handler`需要利用到这个`Context`实例，不仅调用下游的时候需要带上，而且在日志打印逻辑中，也需要输入`Context`实例，从而使得调用信息可以在日志中被打印出。这样一来，调用信息就可以覆盖到整条链路。当我们需要排查调用逻辑问题的时候，就可以把调用信息里某个`key`的值作为日志关键字，从而查到整条链路的日志了。
