---
title: 【从零单排Golang】第十二话：用singleflight解决单服务处理高并发任务的问题
date: 2023/07/01 20:44:17
categories:
- 从零单排Golang
tags:
- Golang
- singleflight
- 并发
- 后端开发
- 源码分析
---

在后端开发场景，我们经常会遇到高并发的事务处理逻辑。虽然在微服务治理的机制下，能够实现多个无状态服务节点+负载均衡高并发处理请求，但对于单个服务节点来讲，如果存在某些耗时的任务需要被高并发访问，那么如果没有一套妥善的机制处理，就很容易出现大量这类任务实例堆积，导致任务返回延迟，或者节点内存暴涨的情况。今天，就来介绍Golang内部处理这种场景的一套方案：singleflight。

## singleflight的应用场景

singleflight主要解决单服务处理高并发任务问题，尤其是服务冷启动时候没有足够请求hit到缓存的场景。假设业务有一个【获取Token】的场景，存在如下的实际约束：

- 访问方式：一个业务（Business），获取一个特定区域（Region）的Token
- Token区域：分为欧亚美非四个区域，每个区域获取Token的时间不一样，但无论怎么输入，都需要【几秒】后才能得到结果
- 访问量级：单个业务下可能存在很多需要获取Token的服务，总的访问这个接口的QPS可能达到【百级或千级】
- 服务数量：你只有【1】个服务节点实例处理这些请求

为了解决这个问题，你可能会考虑通过以下的方式：

<!-- more -->

- 对于一类任务，用一个独特的Key标识：Business+Region
- 当一类任务被触发时，用一个mutex加锁，直到任务完成之后，才解锁
- 用一个map来存储所有任务Key和任务锁
- 如果某类任务在运行时，又被其它来源触发一次，那么这些触发只需要自己做轮询，等任务完成拿结果就行
- 缓存这些任务执行的结果，短期内生效

但这样的方式，实现起来，也是非常麻烦的。而通过singleflight，就可以解决掉除了缓存之外的其它问题。

## singleflight的写法

让我们把上面的场景转化为实际代码来看看。首先，是获取Token的逻辑。

```go
const (
    RegionAmerica = "America"
    RegionEurope  = "Europe"
    RegionAsia    = "Asia"
    RegionAfrica  = "Africa"
)

var mpRegionWaitTime = map[string]time.Duration{
    RegionAmerica: 5 * time.Second,
    RegionEurope:  3 * time.Second,
    RegionAfrica:  4 * time.Second,
    RegionAsia:    2 * time.Second,
}

func getToken(region string, business string) (string, error) {
    waitTime, ok := mpRegionWaitTime[region]
    if !ok || waitTime == 0 {
        return "", errors.New("unsupported region: " + region)
    }
    log.Printf("[getToken] region: %s, business: %s, wait-time: %v", region, business, waitTime)
    time.Sleep(waitTime)
    return fmt.Sprintf("%s|%s|%d", region, business, time.Now().UnixMilli()), nil
}
```

上面的代码含义里，每个region的token，都至少等待2秒钟才能拿到结果。

然后就是用singleflight来解决这个事情了。我们需要把获取token封装成一个Task的形式，通过singleflight的机制来按标识批量处理：

```go
var getTokenGroup singleflight.Group

type GetTokenTask struct {
    Region   string
    Business string
    callback func() (interface{}, error)
}

func (t *GetTokenTask) key() string {
    return fmt.Sprintf("%s|%s", t.Region, t.Business)
}

func (t *GetTokenTask) Do() string {
    key := t.key()
    v, err, _ := getTokenGroup.Do(key, t.callback)
    if err != nil {
        log.Printf("[GetTokenTask] [%s] get token err: %v", key, err)
        return ""
    }
    token, ok := v.(string)
    if !ok {
        log.Printf("[GetTokenTask] [%s] convert token to string err", key)
        return ""
    }
    log.Printf("[GetTokenTask] [%s] got token: %s", key, token)
    return token
}

func newGetTokenTask(region string, business string) *GetTokenTask {
    return &GetTokenTask{
        Region:   region,
        Business: business,
        callback: func() (interface{}, error) {
            return getToken(region, business)
        },
    }
}
```

在这里，每一个GetTokenTask，会有一个对应的任务标识key。我们需要新建一个singleflight.Group实例，并通过实例的Do方法，来封装处理对应key的任务。

通过这样的封装，当某个任务已经在运行的时候，如果其它相同key的任务刚被触发，那么这些任务不会实际运行，而是等待已经运行的任务的有了结果，就直接返回。这样，就节省了任务实际运行的次数了。

我们可以通过一段测试代码来看：

```go
func TestGetToken(t *testing.T) {
    numTasks := 1000

    // 1 business, random region
    business := "gofromzero"
    regions := []string{RegionAmerica, RegionEurope, RegionAsia, RegionAfrica}

    // run multiple tasks
    t.Logf("start %d tasks...", numTasks)
    var wg sync.WaitGroup
    for i := 0; i < numTasks; i++ {
        num := i + 1
        wg.Add(1)
        go func(n int) {
            defer wg.Done()
            idx := n % len(regions)
            region := regions[idx]
            token := GetToken(region, business)
            if token == "" {
                t.Logf("[task:%d] get token failed!", n)
            } else {
                t.Logf("[task:%d] got token -> %s", n, token)
            }
        }(num)
        time.Sleep(1 * time.Millisecond)
    }
    wg.Wait()

    t.Logf("finish!")
}
```

任务总共有1000个，但实际运行到`getToken`函数的次数，仅仅只有4次。这样，就达到了预期的效果。

最后需要注意的是，考虑到一般获取Token的逻辑，Token本身一般会有生效时间。因此最好在`getToken`逻辑中，增加一个缓存结果的逻辑，这样后续的获取Token任务就不必再多等几秒钟才能拿到结果了，可以优先走缓存。

## singleflight的源码分析

singleflight的用法明白了，进阶地，我们可以看一下singleflight源码怎么实现的。

首先是singleflight.Group的定义：

```go
type Group struct {
	mu sync.Mutex       // protects m
	m  map[string]*call // lazily initialized
}

type call struct {
	wg sync.WaitGroup
	val interface{}
	err error
	dups  int
	chans []chan<- Result
}
```

每个singleflight.Group中，会通过一个map来维护任务标识key和任务实例call的关系。

在每个call中，包含以下内容：

- val、err：任务返回的结果
- chans：在通过chan接收返回结果场景下，所有任务的channels（本文未举例，读者有兴趣可自行了解）
- wg：当任务已经在运行时，往后的触发为了等待任务完成需要用的WaitGroup
- dup：这个任务的实际并发量（任务触发+运行过程中总共被触发的次数之和）

通过Do运行任务的逻辑如下：

```go
func (g *Group) Do(key string, fn func() (interface{}, error)) (v interface{}, err error, shared bool) {
	g.mu.Lock()
	if g.m == nil {
		g.m = make(map[string]*call)
	}
	if c, ok := g.m[key]; ok {
		c.dups++
		g.mu.Unlock()
		c.wg.Wait()

		if e, ok := c.err.(*panicError); ok {
			panic(e)
		} else if c.err == errGoexit {
			runtime.Goexit()
		}
		return c.val, c.err, true
	}
	c := new(call)
	c.wg.Add(1)
	g.m[key] = c
	g.mu.Unlock()

	g.doCall(c, key, fn)
	return c.val, c.err, c.dups > 0
}
```

整个逻辑大致如下：

- 任务已经在运行（即`c, ok := g.m[key]; ok`分支）：增加并发计数，等待wg，直接返回结果
- 任务没有运行：初始化call实例，注册到Group中，增加wg计数，doCall运行任务

在doCall中的逻辑如下：

```go
func (g *Group) doCall(c *call, key string, fn func() (interface{}, error)) {
	normalReturn := false
	recovered := false
	defer func() {
		if !normalReturn && !recovered {
			c.err = errGoexit
		}
		g.mu.Lock()
		defer g.mu.Unlock()
		c.wg.Done()
		if g.m[key] == c {
			delete(g.m, key)
		}
		if e, ok := c.err.(*panicError); ok {
			if len(c.chans) > 0 {
				go panic(e)
				select {}
			} else {
				panic(e)
			}
		} else if c.err == errGoexit {
		} else {
			for _, ch := range c.chans {
				ch <- Result{c.val, c.err, c.dups > 0}
			}
		}
	}()
	func() {
		defer func() {
			if !normalReturn {
				if r := recover(); r != nil {
					c.err = newPanicError(r)
				}
			}
		}()
		c.val, c.err = fn()
		normalReturn = true
	}()
	if !normalReturn {
		recovered = true
	}
}
```

过滤掉一些处理runtime异常的逻辑，实际只有这么些关键内容：

- `c.val, c.err = fn()`：执行任务，返回结果
- 转到最外部的defer逻辑 -> `c.wg.Done()`：其它触发的`wg.Wait()`通过了，直接拿到结果返回
- `delete(g.m, key)`，从Group中清除掉自己这个任务实例

这样，整个singleflight的call就完成一组任务处理了。
