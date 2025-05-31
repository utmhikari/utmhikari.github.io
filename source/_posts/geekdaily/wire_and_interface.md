---
title: 【极客日常】分享go开发中wire和interface配合的一些经验
date: 2025/06/01 02:19:33
categories:
- 极客日常
tags:
- Golang
- wire
- interface
- cache
- 依赖注入
---

在先前[一篇文章](https://utmhikari.top/2025/04/04/archiart/go_monorepo_wire/)中，笔者给大家提到了go语言后端编程可以用wire依赖注入模块去简化单例服务的初始化，同时也可以解决服务单例之间复杂依赖的问题。但实事求是来讲，用wire也是有一些学习成本的，wire在帮助解决复杂依赖的问题同时，也会限定你去用一些特定的编程方式来满足wire的需要，尤其需要你interface给用的更加灵活。

因此今天这篇文章，笔者结合自己的经验，就和大家浅分享下，wire和interface配合的一些经验，让大家以后用wire的时候避免一些坑。

<!-- more -->

对于wire的build指令而言，build会检查你依赖对象是属于哪种类型，不能出现重复provide某种类型的情况。也就是说，比如你的某个Service需要一个string的member，那这个string就不好单独provide出来，因为其他Service也大概率存在。所以这种情况下，我们需要通过一个string-provider的interface或者struct去对这个string做一个封装，阐明这个参数的独有业务涵义，这样就不会出现依赖重复的情况。

```go
type ThirdPartyClient struct {
    Client *HttpClient
    Secret string // 初始情况下，需要提供一个secret参数
}

// 一种方式是通过静态config拿，然后wire.Struct给到ThirdPartyClient
type ThirdPartyConfig struct {
    Secret string
}

type ThirdPartyClient struct {
    Client *HttpClient
    Config *ThirdPartyConfig
}

func NewThirdPartyClient(httpClient *HttpClient, config *ThirdPartyConfig) *ThirdPartyClient {
    return &ThirdPartyClient{
        Client: httpClient,
        Config: config,
    }
}

// 另一种方式是抽象一个SecretProvider的interface，可以处理动态获取Secret的情况
type ISecretProvider interface {
    GetSecret() string
}

type ThirdPartyClient struct {
    Client *HttpClient
    SecretProvider ISecretProvider
}

func NewThirdPartyClient(httpClient *HttpClient, secretProvider ISecretProvider) *ThirdPartyClient {
    return &ThirdPartyClient{
        Client: httpClient,
        SecretProvider: secretProvider,
    }
}
```

那这里就衍生出新的问题，如果我有很多Secret，一个SecretProvider不够，那怎么办？这个也好办，因为本质上来讲，对于每一个参与wire的实例，我们都需要阐明其的独有业务涵义。也就是说，你得在ISecretProvider基础上，定义IAAASecretProvider、IBBBSecretProvider以及ICCCSecretProvider这种。或者换个例子，我们wire一些缓存模块给业务service，缓存模块就需要这么设计。

```go
type ICache interface {
    Get(key string) (string, error)
    Set(key string, value string, expiration time.Duration) error
}

type ILocalCache interface {
    ICache
}

type IRemoteCache interface {
    ICache
}

func NewGoCache() ILocalCache {
    // TODO
}

func NewRedisCache() IRemoteCache {
    // TODO
}
```

通过这样写，不仅可以区分LocalCache和RemoteCache，满足wire的要求，同时对于其它开发者，也能够清楚知道当前是使用Local和Remote的Cache来做业务逻辑，这样就不会出现误用。
