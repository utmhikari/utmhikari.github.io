---
title: 【极客日常】再度上手start-fastapi
date: 2020/02/26 22:04:32
categories:
- 极客日常
tags:
- fastapi
- start-fastapi
- python
- 装饰器模式
- 后端
---

近期项目组准备做一个新的工具，因此自个儿做的[start-fastapi](https://github.com/utmhikari/start-fastapi)框架正好能派上用场试试水。在起草需求搭建最初框架的时候也逐步发现原先的start-fastapi有一些不足的地方，因此做了一些针对性的优化。

首先必须重新介绍一下start-fastapi，其本身是轻量级web框架[fastapi](https://github.com/tiangolo/fastapi)的延伸，但是由于fastapi给的例子过于简单，因此就基于此做了一个简单的web后端脚手架，借鉴了[eggjs](https://eggjs.org/zh-cn/intro/quickstart.html)的目录组织模型，使得整个框架更加易于投产。如果稍微看过start-fastapi其中的代码的话就能够发现它并不是一个OOP的框架，这是因为一方面python本身不是向java一般与OO设计理念强耦合，且其module隔离与动态加载机制已经足够区分每一个功能模块了；另一方面轻量的HTTP Web Server本身作为无状态的服务，各个功能模块应该是静态式、单例式的存在。在start-fastapi上也可以继续扩展底层。从起草工具的效果来看，多人协同开发时，每个人负责的模块应当也不会有太大冲突的概率。

接下来是近期优化的一些点，首先是application目录下的优化。原先application分为了service、middleware、config等多个模块，但现在直接缩减为controller、logger跟router，这是因为service跟middleware里全局性的功能模块一般都是用户自定义的，而controller的response可以约定，logger factory也可以统一提供。而router作为后端app的固有功能，这块就必不可少了。

<!-- more -->

然后是controller的优化，在参考了官网的[Bigger Applications](https://fastapi.tiangolo.com/tutorial/bigger-applications/)文档之后，果断把controller写成了经典的装饰器模式。装饰器模式对于业务而言是很大的利好，如果一个新成员协同研发的话就不必在router与controllers之间切来切去。

最后是启动的优化。在start-fastapi的入口中采用uvicorn去启动app程序，但这里疏忽了一个点是uvicorn相当于重新loadfile去载入这个文件里面的python内容，因此如果不把fastapi app的初始化逻辑分离出去相当于加载了两次。分离到根目录`app.py`之后，这个问题就迎刃而解了。

关于uvicorn、starlette、asgi相关的东西，还有许多坑暂时没时间踩，要有空再慢慢瞧瞧了。

---

更新：另外解决了一个分离config配置的原因，现在uvicorn application的配置被分离到`config/app`中，而`config/dev.cfg`与`config/prod.cfg`则是用户定义的配置，采用[python-dotenv](https://github.com/theskumar/python-dotenv)的格式。非常方便，用`os.getenv`就能获取到。
