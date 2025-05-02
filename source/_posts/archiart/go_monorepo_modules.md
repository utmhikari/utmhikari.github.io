---
title: 【架构艺术】Go大仓monorepo各模块的代码组织设计
date: 2025/05/02 14:58:55
categories:
- 架构艺术
tags:
- 架构
- 后端开发
- monorepo
- 编程
- Golang
---

在[先前的文章](https://utmhikari.top/2025/03/09/archiart/go_monorepo_structure/)中，笔者分享了go语言monorepo基本的一套代码架构设计。以这个设计为基础，今天这篇文章就聊一下具体里面的代码怎么编写起来比较舒适。

关于每个微服务自己的代码，其实在[wire依赖注入](https://utmhikari.top/2025/04/04/archiart/go_monorepo_wire/)这篇文章有提到过一套比较简洁的用法。如果大仓对应的服务集群有很多三方依赖，有很多错综复杂的模块的话，对三方依赖做一层抽象，加上用wire去解决重复依赖问题，是最为舒适的一套解法。当然在这个基础上，其它各模块，尤其是公有模块（lib）需要如何做代码实现，这部分是需要额外推敲的，今天这篇文章就浅聊一下。

<!-- more -->

首先先看公有模块的依赖关系如何。最底层的话一般是自动生成的（idl、proto、model之类）以及自己定义的common常量枚举之类，然后再上面是utils，再上面才是三方依赖clients/dal，之后才是具体的业务逻辑。自动生成的这个没法手写，然后common也比较自由，保证在utils之下就可以。

对于utils，这部分比较关键。笔者做代码组织的方式是分三个子层次，分别是：

- 最底层：放到utils下面的子目录，里面放的是基于runtime-libraries往上的一些抽象。比如，对于json数据的各种处理方法，如果一时半会找不到合适的库，就可以自己实现一个，放到这个子目录下面。
- 中间层：即utils当前层次的各种函数，比如有个utils.go文件里面一个GetEnv函数，就属于这一层。这一层函数的作用是把整个服务的通用功能封装起来，可以具备少量的业务性质，尤其是和服务所在环境相关的工具函数，就都放到这一层。
- 最顶层：顶层的utils需要具备一些业务含义，比如结合服务环境和common里面一些业务类枚举，衍生出来的一些业务utils。这类utils的代码组织，可以封装成struct，比如UserUtils，然后再给一个`var User = &UserUtils{}`，这样其它地方调用就可以直接`utils.User.XXXX`来去写，非常简洁明了。

然后再往上三方依赖clients/dal。这部分笔者建议是做自主抽象，比如mysql不要直接暴露gorm.DB，redis也不要暴露go-redis，而是在这些client上面做二次封装，然后把二次封装的client给provide到各个服务里面。这样做的好处，一是可以自主定义一些数据操作，二是可以赋予client更多的业务涵义，这样从每个服务角度，就彻底不需要关心具体数据访问底层怎么实现了。

对于洋葱层的middleware，笔者的建议也是在lib里面单独开一个middleware模块，用来封装服务常用的middleware，比如cors、token+rbac鉴权这种。为什么单独开，原因一是相同的middleware会在多个服务使用，二是比如鉴权的middleware就依赖鉴权client。所以这样最好的方式就是在lib里面开middleware，然后每个服务开服时候去编写`r.Use(middleware.Auth(ctx, jwtClient))`这种样式的代码，这样也非常简洁。

对于service是否要在lib里单开，笔者的想法是不开比较合适。这类纯业务逻辑，要么得下沉到lib.client，要么得上浮到app里面每个子service里面比较合适，比起用代码，更倾向于用服务间的拓扑调用去解释这层关系，服务之间开接口，通过自动生成代码的方式去生成各个服务的client，这样才比较明确每个服务的职责。
