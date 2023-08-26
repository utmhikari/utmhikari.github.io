---
title: 【从零单排Golang】第十四话：使用rate和ratelimit实现限流限速
date: 2023/08/26 15:55:42
categories:
- 从零单排Golang
tags:
- Golang
- 限速
- 限流
- 令牌桶算法
- 漏桶算法
---

在研发中，我们经常会面对到处理并发逻辑的场景，尤其是有时候在与第三方平台对接的场景下，会遇到请求限流限QPS的要求。对于限流或者限速，我们通常会用两种算法来满足需要：

- 令牌桶算法：在特定容量的桶里面装令牌，当令牌数量小于桶的容量时，会持续以我们预期的限流速率生产令牌；不管桶里面是不是空的，业务都得等到拿到令牌，才能继续执行业务逻辑
- 漏桶算法：业务先统一进入桶里，桶满了之后，会以我们预期的限流速率，一个个把在等待的业务漏出去，然后各个业务才开始执行业务逻辑

这两种算法，虽然实际QPS数值可能都会有波动，但都能把速率限制在一个合理的水位。在Golang里面，这两种算法都有现成的实现可以直接用。咱们今天，就来看看这块的例子。

<!-- more -->

首先来看看令牌桶算法，在Golang自带的rate库中，就有了一份令牌桶算法的实现。我们上一下代码的例子，来看一下rate库的基本用法：

```go
import "golang.org/x/time/rate" // 需要import的rate库，其它import暂时忽略

// 生成0->X的数据集
func generateData(num int) []any {
    var data []any
    for i := 0; i < num; i++ {
        data = append(data, i)
    }
    return data
}

// 处理数据，数字*10
func process(obj any) (any, error) {
    integer, ok := obj.(int)
    if !ok {
        return nil, errors.New("invalid integer")
    }
    time.Sleep(1)
    nextInteger := integer * 10
    if integer%99 == 0 {
        return nextInteger, errors.New("not a happy number")
    }
    return nextInteger, nil
}

func TestRate(t *testing.T) {
    limit := rate.Limit(50) // QPS：50
    burst := 25 // 桶容量25
    limiter := rate.NewLimiter(limit, burst)
    size := 500 // 数据量500

    data := generateData(size)
    var wg sync.WaitGroup
    startTime := time.Now()
    for i, item := range data {
        wg.Add(1)
        go func(idx int, obj any) {
            defer wg.Done()
            // 拿到令牌
            if err := limiter.Wait(context.Background()); err != nil {
                t.Logf("[%d] [EXCEPTION] wait err: %v", idx, err)
            }
            // 执行业务逻辑
            processed, err := process(obj)
            if err != nil {
                t.Logf("[%d] [ERROR] processed: %v, err: %v", idx, processed, err)
            } else {
                t.Logf("[%d] [OK] processed: %v", idx, processed)
            }
        }(i, item)
    }
    wg.Wait()
    endTime := time.Now()
    t.Logf("start: %v, end: %v, seconds: %v", startTime, endTime, endTime.Sub(startTime).Seconds())
}
```

通过`limiter := rate.NewLimiter(limit, burst)`的形式，我们可以初始化一个令牌生成速率为limit，容量为burst的令牌桶。在业务里，则通过`limiter.Wait(ctx)`的方式拿到一个令牌，执行逻辑。结合先前讲过的[WaitGroup](https://utmhikari.top/2023/08/06/gofromzero/13_waitgroup/)，我们就能够实现开多个goroutine异步执行任务，并配合limiter来做业务逻辑的限速。

这里需要注意，从长线来看，limit的大小是能够决定一个基础的限速速率，但从短线角度来看，burst这个桶具备了缓冲作用，在冷启动时，由于burst的存在，初始的QPS会比实际预估的较大。因此，业务通过令牌桶方式限速时，如果需要限制冷启动时的瞬时速率，需要留意把burst的值设置小一些。

然后我们再来看通过漏桶算法来限速的例子，这回需要用到一个开源库[uber-go/ratelimit](https://github.com/uber-go/ratelimit)来实现。例子也非常简单，代码如下：

```go
func TestRateLimit(t *testing.T) {
    limiter := ratelimit.New(50) // 漏桶速率50
    size := 500

    data := generateData(size)
    var wg sync.WaitGroup
    startTime := time.Now()
    for i, item := range data {
        wg.Add(1)
        go func(idx int, obj any) {
            defer wg.Done()
            limiter.Take() // 入桶待漏
            processed, err := process(obj)
            if err != nil {
                t.Logf("[%d] [ERROR] processed: %v, err: %v", idx, processed, err)
            } else {
                t.Logf("[%d] [OK] processed: %v", idx, processed)
            }
        }(i, item)
    }
    wg.Wait()
    endTime := time.Now()
    t.Logf("start: %v, end: %v, seconds: %v", startTime, endTime, endTime.Sub(startTime).Seconds())
}
```

`ratelimit`库速率的单位可以类比为QPS，通过`ratelimit.New`，可以初始化一个指定QPS限制的限流器。执行业务逻辑前，需要通过`limiter.Take()`逻辑等待漏出来后，才能执行后续的逻辑。这样便实现了限流的效果。
