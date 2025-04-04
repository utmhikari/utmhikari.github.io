---
title: 【从零单排Golang】第五话：用自带net包写一个简单的负载均衡
date: 2019/11/24 12:28:04
categories:
- 从零单排Golang
tags:
- Golang
- 并发
- tcp
- 负载均衡
- 后端开发
---

## 前言

[Github传送门](https://github.com/utmhikari/gofromzero)

golang在工业中用途最多的方面就是编写中间件以及上游设施，因此切入golang的话，了解其网络库是很有必要的。因此，笔者上手了自带的net包，花了一天左右的时间写了个简单的[负载均衡（Load Balancer）](https://zh.wikipedia.org/wiki/%E8%B4%9F%E8%BD%BD%E5%9D%87%E8%A1%A1)，也算是能用啦= =

## 用net包写负载均衡

我们在浏览网页时，通常会遇到服务方故障的情况，提示我们nginx、apache之类的字眼。这些，便都是负载均衡的工作了。

一个负载均衡可能会包含以下的功能：

- 负载调节
  - 上游连接分配（策略：轮流（roundrobin）、最少连接等）
  - 权重管理
- 健康检查（业务是否OK）
- 协议支持
  - tcp、udp
  - http、https
  - 路由代理
  - 数据缓存与压缩
- 安全
  - 限流，DDOS防护
  - 备用负载均衡

为了实践一下（培养手感），笔者用net包弄了一个基于tcp的简易负载均衡，实现了上述最基础的负载调节与健康检查功能。

首先设计一个struct：

<!-- more -->

```go
type loadBalancer struct {
    Port uint
    Listener net.Listener
    ServerMap map[uint]*Server
}
```

除了用于listen的端口与listener实例之外，用一个map储存每一个服务的信息与状态。虽然粒度有点大，但凑合能用。

每一个服务包含了地址、权重、是否活跃等信息：

```go
type Server struct {
    ID uint
    Active bool
    Host string `json:"host"`
    Port uint `json:"port"`
    Weight float64 `json:"weight"`
}
```

通过一个配置文件，可以生成一个不accept但listen的负载均衡实例：

```go
// 初始化负载均衡实例
func NewLoadBalancerOnConfig(configPath string) (*loadBalancer, error) {
    // load config
    lb, err := initLoadBalancer(configPath)
    if err != nil {
        return nil, err
    }
    // listen but not accept
    addr := fmt.Sprintf("0.0.0.0:%d", lb.Port)
    server, err := net.Listen(network, addr)
    if err != nil {
        return lb, err
    }
    lb.Listener = server
    log.Printf("Load balancer is ready at %s...\n", addr)
    go lb.healthCheck()
    return lb, nil
}
```

其中注意到，启动实例后，会直接开启健康检查任务，这样就能实现上游服务信息的初始化，让我们一开始就能够了解哪些上游服务可用（active）。

```go
// 健康检查——轮询每个服务
func (lb *loadBalancer) healthCheck() {
    for {
        var wg sync.WaitGroup
        wg.Add(len(lb.ServerMap))
        for id, server := range lb.ServerMap {
            tmpID := id
            tmpServer := server
            go func() {
                defer wg.Done()
                addr := tmpServer.GetAddr()
                conn, err := net.DialTimeout(network, addr, dialTimeout)
                mtx.Lock()
                if err != nil {
                    log.Printf("Health check failed at server %d (%s): %s\n",
                        tmpID, addr, err.Error())
                    lb.setInactive(tmpID)
                } else {
                    log.Printf("Health check success at server %d (%s)!",
                        tmpID, addr)
                    lb.setActive(tmpID)
                    defer func() {
                        _ = conn.Close()
                    }()
                }
                mtx.Unlock()
            }()
        }
        wg.Wait()
        time.Sleep(healthCheckInterval)
    }
}
```

之后，用户需要调用`Run()`，才能真正接受外界连接。

```go
// 启动负载均衡服务
func (lb *loadBalancer) Run() {
    defer func() {
        if err := lb.Listener.Close(); err != nil {
            log.Printf("Error while closing load balancer! %s\n", err.Error())
        }
    }()
    log.Printf("Load balancer will be launched after 3 seconds...")
    time.Sleep(3 * time.Second)
    runtime.GOMAXPROCS(3)
    var clientID uint
    for {
        conn, err := lb.Listener.Accept()
        if err != nil {
            log.Printf("Error while accepting connection! %s\n", err.Error())
        }
        clientID++
        go handler(conn, clientID, lb)
    }
}
```

在每一个连接的handler中，会新增一个转发器forwarder，采取最少连接数策略连接上游服务，在程序中是选中权重最低的，尽可能active的那一个。由于“连接”是一个阻塞操作，因此我们乐观地认为所有连接都趋向于成功，在连接之前增加权重：

```go
// 处理客户端连接
func handler(conn net.Conn, clientID uint, lb *loadBalancer) {
    addrString := getAddrString(conn)
    // allocate a server for forwarding data
    var forwarder net.Conn
    mtx.Lock()
    serverID := lb.SelectServerID()
    serverAddr := lb.ServerMap[serverID].GetAddr()
    lb.weighConnect(serverID)
    mtx.Unlock()
    // 以下略
}
```

如果连接成功则保持，连接失败则减去权重。成功后，通过forward方法，把用户连接的数据转发给相应的服务，并且也会把服务器write的数据转发给用户：

```go
// 转发客户端数据
func forward(conn net.Conn, forwarder net.Conn, clientID uint, serverID uint, lb *loadBalancer) {
    clientAddr := getAddrString(conn)
    serverAddr := lb.ServerMap[serverID].GetAddr()
    defer func() {
        log.Printf("[%d] %s disconnected from %s\n",
            clientID, clientAddr, serverAddr)
        mtx.Lock()
        lb.weighDisconnect(serverID)
        mtx.Unlock()
        lb.PrintServers()
    }()
    var wg sync.WaitGroup
    var errCode int32 = 0
    callback := func() {
        _ = conn.Close()
        _ = forwarder.Close()
        wg.Done()
    }
    wg.Add(2)
    // request
    go func() {
        defer callback()
        var b = make([]byte, bufferSize)
        for {
            n, readErr := conn.Read(b)
            if readErr != nil {
                atomic.CompareAndSwapInt32(&errCode, 0, ReadC2FError)
                log.Printf("[%d] Read c2f error from %s: %s",
                    clientID, clientAddr, readErr.Error())
                break
            }
            _, writeErr := forwarder.Write(b[:n])
            if writeErr != nil {
                atomic.CompareAndSwapInt32(&errCode, 0, WriteF2SError)
                log.Printf("[%d] Write f2s error to %s: %s",
                    clientID, serverAddr, writeErr.Error())
                break
            }
        }
    }()
    // response
    go func() {
        defer callback()
        var b = make([]byte, bufferSize)
        for {
            n, readErr := forwarder.Read(b)
            if readErr != nil {
                atomic.CompareAndSwapInt32(&errCode, 0, ReadS2FError)
                log.Printf("[%d] Read s2f error from %s: %s",
                    clientID, serverAddr, readErr.Error())
                break
            }
            _, writeErr := conn.Write(b[:n])
            if writeErr != nil {
                atomic.CompareAndSwapInt32(&errCode, 0, WriteF2CError)
                log.Printf("[%d] Write f2c error to %s: %s",
                    clientID, clientAddr, writeErr.Error())
                break
            }
        }
    }()
    wg.Wait()
    fmt.Printf("[%d] Closed on signal: %d\n", clientID, errCode)
}
```

这样，一个简易的负载均衡就完成了。

## 总结

上述的负载均衡还存在许多问题，从语言上来讲，比如：

- 并行/并发锁粒度太大
- 可以用一些相对封装较好的实例，如net.Dialer
- 可以利用golang自带channel、context等机制

而从业务上来讲，模块耦合较多，扩展性会差一点。并且真正完备的负载均衡设施，还需要考虑很复杂的功能，这些都需要一个个模块好好设计来实现的。

不论是语言层面还是业务层面都有很多的提升空间。加油吧~
