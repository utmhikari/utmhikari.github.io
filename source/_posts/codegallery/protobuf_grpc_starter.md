---
title: 【代码艺廊】Protobuf+GRPC应用范例：protobuf-grpc-starter
date: 2021/04/02 00:55:52
categories:
- 代码艺廊
tags:
- Golang
- protobuf
- grpc
- 后端开发
- gin
---

后端的服务间通常采用固定的协议&rpc框架通信，当前主流的方案是以[protobuf](https://github.com/golang/protobuf)协议为基础，采用[grpc](https://www.grpc.io/)进行通信，这种方式在Golang的开发中尤其突出。因此，笔者决定做一个小的golang应用来踩坑protobuf+grpc编码模式，上传到github分享——这便是[protobuf-grpc-starter](https://github.com/utmhikari/protobuf-grpc-starter)。

protobuf-grpc-starter主要受到了[PasteBin](https://pastebin.com/)的启发，用户post一段代码到服务器，得到一个短链接（shortLink），其它用户可以通过这个短链接取查看这个用户所发送的代码，实现代码文本分享。当存储文本量较大、且用户访问量较多时，数据库不一定能够承载的了查询的压力，这样就需要缓存来分担查询的任务。因此在protobuf-grpc-starter中，笔者编写了两个小server：WebSvr和CacheSvr，其中WebSvr用于处理用户的查询以及post文本请求，post的文本存储在单独的文件中；CacheSvr则在内部实现了一个驻留内存的LRU缓存，用来缓存短链接查询的结果（短链接only，保证强一致）。WebSvr和CacheSvr间基于protobuf协议采用[grpc-go](https://github.com/grpc/grpc-go)框架通信，处理获取/设定查询缓存的操作。为了保证新接触protobuf+grpc的同学能够专注于此，这个项目的prerequisities里也不会引入类似redis的中间件，而只有go、grpc、protobuf等相关的内容，包括：

- golang v1.16：有最新的库和特性
- protoc：用来编译protobuf协议文件，需要在[protoc下载地址](https://developers.google.com/protocol-buffers/docs/downloads)下载较新的版本（protobuf3）
- protoc-gen-go：用来生成golang的协议定义文件，可以在[protobuf-go教程](https://developers.google.com/protocol-buffers/docs/gotutorial)了解如何下载及生成文件
- protoc-gen-go-grpc：用来生成golang的协议grpc定义的文件，可以在[grpc-go教程](https://grpc.io/docs/languages/go/quickstart/)了解如何下载及生成文件
- make：项目里用了Makefile，因此需要支持make。Makefile里包含了文件生成（proto）以及服务器二进制文件生成（server）的指令

整个项目的结构如下：

<!-- more -->

![protobuf_grpc_starter](/uploads/codegallery/protobuf_grpc_starter/structure.png)

要体验项目，安装相关prerequisities之后，执行make编译生成协议go文件，并生成websvr与cachesvr的二进制文件。先执行cachesvr，再执行websvr，而后用户可以通过http client向websvr发送请求来观察两个服务的日志及状态。websvr的http服务器采用[gin](https://github.com/gin-gonic/gin)框架，通过`main.go`源码可以直接查阅每个路由对应的handler以及内部逻辑。在这个项目里，针对用户角度的用例如下：

- post文本（document）：websvr会直接尝试将文本存储到DB（追加到文件）中，如果成功则返回一个短链接shortLink
- 查询document(s)：分两种情况
  - 不包含shortLink：取出DB文件所有内容，遍历查询所有符合query的document，返回一个document列表
  - 包含shortLink
    - 调用CacheSvr的GetDocument函数尝试获取缓存的document。如果成功，直接返回这个document
    - 如果不成功，则取出DB文件所有内容，遍历查询，直到有包含该shortLink的document为止
    - 如果找到了，调用CacheSvr的SetDocument将这个document设置到缓存里，然后返回这个document。如果找不到，就返回错误

WebSvr和CacheSvr之间的grpc连接，参照了grpc-go中的[范例](https://github.com/grpc/grpc-go/blob/master/examples/features/keepalive)保持了长连接状态。调用CacheSvr函数的过程，也便是protobuf+grpc通信的过程。更多的信息，可以在[protobuf-grpc-starter的github](https://github.com/utmhikari/protobuf-grpc-starter)深入挖掘。

第一次踩坑这块的内容，纯属抛砖引玉，有疏漏之处，还需见谅~
