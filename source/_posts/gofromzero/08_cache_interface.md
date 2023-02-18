---
title: 【从零单排Golang】第八话：通过cache缓存模块示范interface该怎么用
date: 2023/02/18 02:16:48
categories:
- 从零单排Golang
tags:
- Golang
- interface
- cache
- go-cache
- 依赖注入
---

和许多面向对象的编程语言一样，`Golang`也存在`interface`接口这样的概念。`interface`相当于是一个中间层，下游只需要关心`interface`实现了什么行为，利用这些行为做些业务级别事情，而上游则负责实现`interface`，把这些行为具象化。本文就来通过一个简单的缓存`cache`模块的实现，来示范一下`Golang`的`interface`该怎么用。

首先，从业务`service`角度而言，一个cache模块可能需要以下几种方法：

- 获取缓存中的某个值
- 缓存数据，加缓存时效
- 删除缓存内容

那么这些个方法，就可以用一类叫`Cache`的`interface`来表示：

<!-- more -->

```go
type Cache interface {
    Get(key string) (interface{}, bool)
    Set(key string, value interface{})
    SetExpire(key string, value interface{}, expire time.Duration)
    Delete(key string)
}
```

其中，`Get`方法返回一个`interface{}`的`value`，以及是否存在的`bool`标识；`Set`跟`SetExpire`表示无时限跟有时限的缓存行为；`Delete`表示删除缓存内容。整块`Cache`的接口定义也非常明显。

这样写有什么好处？如果你是下游业务服务的话，你只需要这样写就可以了。这里给一个同`package`下的测试用例代码：

```go
func TestCache(t *testing.T) {
    k, v := "hello", "world"
    // Current()的实现，在下文慢慢解释
    var curCache Cache = Current()

    // set & get & delete
    curCache.Set(k, v)
    cached, ok := curCache.Get(k)
    if !ok {
        t.Fatalf("cannot cache %s:%s", k, v)
    } else {
        t.Logf("got cached %s:%v (type: %s)", k, cached, reflect.TypeOf(cached).Name())
    }
    curCache.Delete(k)
    _, ok = curCache.Get(k)
    if ok {
        t.Fatalf("cannot delete %s:%s", k, v)
    } else {
        t.Logf("delete cached %s:%s", k, v)
    }

    // set expire
    curCache.SetExpire(k, v, 1*time.Second)
    cached, ok = curCache.Get(k)
    if !ok {
        t.Fatalf("cannot cache %s:%s", k, v)
    } else {
        t.Logf("got cached %s:%v (type: %s)", k, cached, reflect.TypeOf(cached).Name())
    }
    time.Sleep(3 * time.Second)
    _, ok = curCache.Get(k)
    if ok {
        t.Fatalf("cannot expire %s:%s", k, v)
    } else {
        t.Logf("expired %s:%s", k, v)
    }
}
```

可以看到，我们指定的缓存对象`curCache`标识为一个`Cache`，是个接口定义，这样标识起来的话，下面的代码就可以正常使用`Get`、`Set`之类的方法了。而更重要的是，下面的代码，不会因为`Cache`的具体实现变化而有所变化。举个例子，你有10个开源的缓存库，想定时切换`Current() Cache`背后的缓存对象实现，就算你再怎么换，只要用到缓存的代码标注缓存对象为`Cache`这个`interface`，并且`interface`的定义没有变化，那么使用缓存的代码就不需要动。这样，就彻底实现了缓存提供方和使用方的解耦，开发效率也会噌噌噌的上去。

既然提到了提供方`Provider`的概念，那在缓存的实现上，就可以走依赖注入控制反转的模式。假设某个Web服务有个本地缓存模块，在实现上，就可以考虑提供多个`Cache`接口的实现，同时在配置里指定默认的一种。这里，就以[go-cache](https://github.com/patrickmn/go-cache)为例，做一个实现案例。

```go
import (
    "github.com/patrickmn/go-cache"
    "time"
)

const (
    GoCacheDefaultExpiration = 10 * time.Minute
    GoCacheCleanupInterval   = 15 * time.Minute
)

type GoCache struct {
    c *cache.Cache

    defaultExpiration time.Duration
    cleanupInterval   time.Duration
}

func (g *GoCache) Get(key string) (interface{}, bool) {
    return g.c.Get(key)
}

func (g *GoCache) Set(key string, value interface{}) {
    g.c.Set(key, value, GoCacheDefaultExpiration)
}

func (g *GoCache) SetExpire(key string, value interface{}, expire time.Duration) {
    if expire < 0 {
        expire = g.defaultExpiration
    }
    if expire > g.cleanupInterval {
        expire = g.cleanupInterval
    }
    g.c.Set(key, value, expire)
}

func (g *GoCache) Delete(key string) {
    g.c.Delete(key)
}

func NewGoCache() *GoCache {
    return &GoCache{
        c: cache.New(GoCacheDefaultExpiration, GoCacheCleanupInterval),

        defaultExpiration: GoCacheDefaultExpiration,
        cleanupInterval:   GoCacheCleanupInterval,
    }
}
```

当我们定义一个`GoCache`的`struct`，实现了`Cache`接口定义的所有行为，那么`GoCache`的实例，在`Golang`里，就能够被标识为一个`Cache`接口实例。`NewGoCache`方法，不仅是提供了一个`GoCache`的实例，而在业务层面，更是提供了一个`Cache`实例。因此，我们可以简单用一个`map`来管理所有的`Cache`的构造器，从而标识不同的缓存实现：

```go
func provideGoCache() Cache {
    return NewGoCache()
}

var cacheProviders = map[string]Cache{
    "go-cache": provideGoCache(),
}

const (
    DefaultCacheProvider = "go-cache"
)

func Get(provider string) Cache {
    c, ok := cacheProviders[provider]
    if !ok {
        return nil
    }
    return c
}

func Default() Cache {
    return Get(DefaultCacheProvider)
}

// 上文提到的样例代码，就用了这个方法拿到go-cache实现的Cache接口实例
func Current() Cache {
    return Default()
}
```

显而易见，通过这样的一个代码组织，不论是`go-cache`，抑或是其它的`Cache`实现，都可以集中管理并灵活取用。这，便是`interface`在`Golang`编程中给我们带来的便利了。
