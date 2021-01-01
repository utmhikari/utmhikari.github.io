---
title: 【代码艺廊】代码仓库管理小工具repomaster
date: 2021/01/01 22:43:56
categories:
- 代码艺廊
tags:
- Golang
- 工具开发
- git
- gin
- go-git
---

呼吸不停，coding不止。代码艺廊新系列，将要用来陈列自己的大小作品；极客日常系列，则专门用于分享新的技术心得。开年第一作，介绍一个自制用于管理代码仓库的小工具[repomaster](https://github.com/utmhikari/repomaster)。

代码仓库管理在许多场景能够用到，比如用作构建集群的文件缓存、构建配置的代码仓库服务、配置导出与检查等等，其中最后一种需求在游戏QA的工作场景（导表检查）会是一个比较重要的需求，而repomaster的设计方式也会更加贴合管理大量同一个repo不同checkout副本的情况。作为一个纯靠内存作为缓存，无需持久化数据的应用，repomaster在技术选型上，Golang一定是最合适的语言（共享内存+方便的并发控制）。只需要少量的代码，就能够搭起来架子。

当前的repomaster已经具备如下的功能：

<!-- more -->

- 代码仓库缓存与刷新：用[sync.Map](https://golang.org/src/sync/map.go)就能够简单处理。每一个仓库都clone到特定数字文件夹当中，以文件夹名的数字作为key来存储每一个repo信息
- 代码仓库的拉取、更新、容错处理：当前支持git，以[go-git](https://github.com/go-git/go-git)作为主要类库实现。由于go-git的内部接口较复杂，建议二次开发增加采用执行shell cmd的方式兜底。
- 代码仓库文件信息导出
- 采用[gin](https://github.com/gin-gonic/gin)作为网络框架，稳定对外提供HTTP服务

当前repomaster已经实现了缓存管理及git的支持，如果有需要适配特定业务的需求，可以直接在repomaster的service与handler模块上进行扩展。当前的实现也有很多优化扩展的空间，未来的维护计划，也希望把更多的Golang特性应用到repomaster当中。
