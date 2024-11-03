---
title: 【极客日常】Golang一个的slice数据替换的bug排查
date: 2024/07/20 23:16:47
categories:
- 极客日常
tags:
- Golang
- 重构
- slice
- 问题排查
- 指针
---

上周某天下班前，接到同事转来一个bug要排查，症状是代码重构之后某些业务效果不符合预期，由于代码重构人是笔者，于是blame到笔者这边。经过10min左右的排查和尝试后，解决了这个问题：既往逻辑没有改动，重构时候出笔误了。

简单来讲，重构之前的代码大概是这个样子：

<!-- more -->

```go
func beforeRefactor() {
    var configListExpr = fetchConfigListExpr()
    
    newConfigListExpr := replaceConfigVariables(configListExpr)

    var configList []Config
    if err := json.Unmarshal([]byte(newConfigListExpr), &configList); err != nil {
        panic("unmarshal configList err: " + err.Error())
    }
    return configList
}
```

而改造业务逻辑时，因为类似于replaceVariables这类对configList批量处理的流程更多，所以定义了很多函数节点去对configList做批量的替换以及内部属性的修改。因此重构时候，就把replaceConfigVariables做了更细粒度的转换，然后同时把整个configList替换逻辑也顺带修改了下。大概改成了这样：

```go
func afterRefactor() {
    var configList []Config = fetchConfigList()

    for _, config := range configList {
        urlList := config.URLList
        newURLList = replaceURLListVariables(urlList)
        config.URLList = newURLList
    }

    return configList
}
```

这段代码是存在问题的。由于这次重构提的代码很多，cr时候没有发现；然后一开始排查以为是重构引起的业务逻辑变更，所以忽略了Golang本身机制导致的问题。这里的问题是，遍历slice的时候，要想改动原来slice里成员的属性，不应该用config这个复制品，而得用configList取下标这种方式来取到原始的成员实例，或者干脆把configList整个全新替换，这样才可以达到效果。
