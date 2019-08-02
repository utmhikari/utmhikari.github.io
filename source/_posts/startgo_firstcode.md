---
title: 【从零单排Go】第一话：HelloWorld？环境配置与依赖管理踩坑
date: 2019/07/20 19:35:05
categories:
- 从零单排Go
tags:
- Go
- 环境变量
- VSCode Go
- go package
- go mod
---

## 前言

当测试开发真不容易，入行第一年，就要在python、NodeJS、lua、C、Java等语言间无缝切换。为了快速响应需求，挺难抽出时间去深耕一门语言的特性（诶羡慕那些只搞Java的人= =）。在[MTSC2019分享](https://utmhikari.github.io/2019/07/01/testlife_mtsc2019/)中也谈到，测试开发归属质量保障QA，作为一个中台角色，其终极任务保障研发效能，因此一大需求是打通产品研发运维的生产线。说到生产线就想到上云，说到上云就想到docker跟kube，说到跟容器的交互就想到了Golang。马蛋，又要学一门新语言了。

开这个坑，旨在展现以程序员的视角学习一门新语言的过程。希望大家看得欢乐。如果有启发，那就更棒啦！

## 安装与环境变量配置

家里的电脑是Windows，从[官网](https://golang.org/)即可下载Win的安装包。Go的版本为1.12。

下好后安装，安装完毕之后还需要设置环境变量（我的电脑——属性——高级系统设置）。`GOROOT`设置成Go的安装路径，还有一个关键的`GOPATH`，它表示你的工作目录，**一般所有的Go项目，甭管第三方的还是你的，都统一放到这个目录下**（从这点可以看出，Go的控制欲还是很强的）。`GOPATH`的一般结构如下：

<!-- more -->

- GOPATH
  - bin 可执行文件目录
  - src 源码目录

一般来讲我们可以在`%GOPATH%\src`下新开一个自己的文件夹存放我们以后的Go项目源码。而对于可执行文件，我们可以在环境变量`PATH`中增加`%GOPATH%\bin`跟`%GOROOT%\bin`保证在cmd里能直接运行。

## 配置VSCode环境

Golang用的IDE的话idea跟VSCode都ok，家里就用VSCode好了。这里直接在`GOPATH`下建立了一个`mytest`文件夹当作我们的测试项目，用VSCode打开，然后添加一个Go脚本`main.go`，内容就是我们见到最多的：

```go
package main

import "fmt"

func main() {
   fmt.Println("Hell World")
}
```

这个时候VSCode就会提示下一堆工具依赖了（linter、自动填充之类）。但是VSCode插件默认会从go source下载。由于众所周知的不可抗力一般下载不行，但有其它的解决方法：

- 测一下github网速，实在不行请开启游戏加速器
- 查看VSCode输出日志——看看哪些依赖安装失败。一般由于不可抗力，`golang.org/x/tools/`之类的google官方依赖会下不到。这个时候需要在`%GOPATH%\src`下建立`golang.org/x`目录，然后再从github上对应的仓库克隆`github.com/golang/tools`，然后go install。可以参考：[VSCode + Golang配置](https://blog.csdn.net/u013295518/article/details/78766086)
- 像`gocode-gomod`等binary（exe），可以直接copy gocode改个名字就能用

万事开头难，一劳永逸，弄好这些就基本可以直接开搞了。VSCode还是很方便的，比如配合golint优化代码，代码规范的事情就完全不用担心了。

## package import

再基于上面的mytest给个例子，文件结构如下：

- GOPATH
  - src
    - mytest
      - main.go
      - hello
        - hello.go

在Golang里，**单个目录下的直属go文件（也就是不包括子目录下的go文件），都必须只属于一个package**。Golang在import package时，本质也就是import一个目录啦，它会分别以`%GOROOT%\src`以及`%GOPATH%\src`为根目录开始寻找package。像`fmt`之类的标准库就在`%GOROOT%\src`中，而我们自己下的依赖就在`%GOPATH%\src`中。

根据上面的文件结构，我们可以在`hello.go`中填充内容：

```go
package hello

import (
    "fmt"
)

// Hello
func Hello(s string) {
    fmt.Printf("Hell%s World", s)
}
```

`hello.go`属于hello这个package，然后包含一个叫`Hello`的函数，这个函数具体干了什么相信大家都明白。然而里面其实有几个坑——**Go约定public函数名称开头得大写**，比如这个`Hello(s string)`写成`hello`的话，就成了private函数了。

在`main.go`调用`Hello`函数的话，可以这样：

```go
package main

import (
    "mytest/hello"
)

func main() {
    var s string
    s = ""
    hello.Hello(s)
}
```

我们import的是`mytest/hello`，也就是相对于`%GOPATH%\src`的文件夹路径，就可以把package hello给引入。要调用的话，只需`hello.Hello`即可~

## 依赖管理

开发期我们常需要引入第三方库。python有virtualenv，Node有npm + package.json + node_modules，Java有Maven，那Golang里用什么解决方案呢？

四处寻觅了一下，目前有许多vender式的方案（类似node_modules），比如[dep](https://github.com/golang/dep)跟[glide](https://github.com/Masterminds/glide)，而现今主推的方案是1.11版本后的go mod指令。首先，需要设置环境变量`GOMOD111MODULE`为`on`，然后增加一个代理，设置`GOPROXY`为`https://goproxy.io`，这样就能便捷下载依赖了。

以安装后端框架[gin](https://github.com/gin-gonic/gin)为例，首先进入刚刚的mytest，直接`go mod init`，即可将之标为模块。值得注意的是，刚刚环境变量`GOMOD111MODULE`设为`on`后需要标识模块，里面的lib才能被import。

而后，copy gin的示例代码到`main.go`，直接`go run main.go`，依赖就会自动安装了。

## 总结

诶，对于开发者来说有一个舒服的开发环境是很重要的。后面再慢慢研究语言跟各种轮子的特性~
