---
title: 【代码艺廊】start-fastapi升级，对FastAPI应用开发的全新理解
date: 2021/01/24 21:36:32
categories:
- 代码艺廊
tags:
- python
- fastapi
- start-fastapi
- 后端开发
- 工具开发
---

2021，新的开始，曾经精心制作的轻量级web后端框架[start-fastapi](https://github.com/utmhikari/start-fastapi)也经历了一次升级。这次升级，是基于这一年来使用start-fastapi开发以及应用与业务工作的经验，对已有框架进行的结构性的优化。

start-fastapi，甚至是[FastAPI](https://fastapi.tiangolo.com/)本身，其专注的方面都是在快速实现轻量级应用当中。在升级后2021版的结构中，针对如何更加效率地组成FastAPI应用，下了很多手笔。我们可以一探究竟：

<!-- more -->

升级版start-fastapi第一层只保留了4个目录：app、cfg、core、misc。app目录和core目录，都包含controller/handler、model和service，但区别在于，用户需要把项目专有的逻辑放到app目录下，而在core中编写底层逻辑，这样如果要用start-fastapi编写另外一个项目，那么python代码方面，core整个都可以copy过去，减少了项目迁移的成本。
cfg为配置目录，其二层目录名称代表着不同的运行环境，每个运行环境下包含一组相同文件名的配置集，这样能够易于管理各个环境的配置。所有部署、文档、开发资源等内容，统一放到misc目录下，通过这种方式，可以让开发者更加专注于业务逻辑的编写上。

除了目录方面的改动之外，也增加了如下内容，让用户更加方便地组成各类逻辑：

- 增加response的基类、内部通用返回值的类型定义（success, message, data）。实现某些通用接口的时候，这些数据结构就能派上用场
- 抽象与框架相关的，和一些经常用到的工具函数，统一放到core的lib中，这样编写业务逻辑，就没有必要import一堆东西了
- 增加一个事务服务的模板（trans service），用来管理/监控各类需要通过fastapi的background task运行的任务。
- 增加一个生成handler、model、service代码模板的脚本，实现快速编程
- etc

更多的细节，clone/fork源码，细细挖掘吧~
