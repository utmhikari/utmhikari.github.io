---
title: 【架构艺术】服务架构稳定性的基础保障
date: 2024/11/03 12:11:40
categories:
- 架构艺术
tags:
- 架构
- 后端开发
- 微服务
- 稳定性
- 问题排查
---

一个产品随着不断研发，其服务架构的复杂度会越来越高。随着产品的用户体量变大，为了保证产品能够长线运营，就需要保证整个服务架构的稳定性。因此，今天这篇文章，就从实操的角度，粗浅讨论一下，服务架构的稳定性需要如何做到基础保障。

既然是基于实操的角度，那么理论上的东西不会涉及的太深刻。好比说，谈到稳定性，我们就会考虑SLI、SLO、SLA这些基础概念，但这些比较宏观。拿OKR举例子的话，O是SLA，KR是SLO，而SLI则是KR具体的指标定义。所以这篇文章主要讲如何保证SLI以及其他指标，间接满足SLO、SLA的需要。

<!-- more -->

对于外部客户来讲，核心服务的SLI指标是需要优先保证的，而周边服务的SLI指标则可以做为核心服务的下钻指标来看待。SLI指标一般是上游视角的服务可用性，如果一个请求返回一些4字头、5字头的错误码，那么就可以认为上游视角服务不可用。由于5字头主要是服务器错误，因此5字头的问题需要case-by-case排查服务端实现问题进行处理，而4字头则不一定。比如一个只能POST的路由，强行GET，就有可能构造出一个404；一个设计上预计延时较长的接口，客户端如果提前断开，nginx也可能给一个499的错误。究其性质，4字头的错误可以适当做过滤，但也不排服务端自己可以把接口实现给优化掉，主动解决问题。

为了保证SLI的高指标，刚刚提到，除了周边服务的SLI指标外，其他当前服务的黄金指标也必不可少。上下游的请求错误，可以反映当前服务具体出现哪些错误或者不合理的请求，以及服务处理业务过程中哪些环节出了异常；容器的CPU/MEM等资源占用，可以反映服务在哪些具体的时刻出现性能问题；错误和崩溃日志，则直接反映具体出现的业务逻辑或者性能问题是什么。

对于SLI的毛刺，可以将同一时间段三类下钻指标结合起来看，找到一些毛刺上的共性，对于请求错误，可以找到一些trace的例子做分析；对于性能占用问题，可以通过抓取火焰图来看当前某个时间段哪些函数占用的时间比较多，然后再做定点优化；对于错误崩溃日志问题，可以做日志聚合分析，看哪些类型的日志出现的比较多，哪些日志在某个时刻有上涨波动，找到一些关键字共性特征。这样，就可以系统性查证可能导致可用性降低的原因，从而逐个排除击破。

除了核心服务和周边服务之外，中间件的问题也是需要关注的，比如DB的表可用性、消息队列的吞吐量延时，以及缓存的访问错误率等等。对于DB而言，可以重点关注慢查询、连接数上限和主从延时等性能指标，如果有慢查或者连接数打满那要考虑代码hit索引以及连接（池）未及时释放问题，是需要服务器关心的，如果有主从延时，则需要看是不是同时刻有DDL之类的操作锁表，导致大量数据不能及时同步，或者纯粹是DB运维原因。对于缓存而言，如果缓存访问错误，可以优先看下是否因为高延时引起，如果是的话，看下是否有大key占用了缓存较多的内存，或者频繁对于大key做操作导致缓存处理不过来。之后，DB和缓存都需要注意集群分片的场景下，单个实例的性能问题，需要考虑是否存在某些热点数据。

对于消息队列，除了运维原因外，尤其是作为消费者的服务，需要监控上消费逻辑的处理延时。尤其，如果消费逻辑涉及到和第三方平台的交互，需要考虑第三方平台是否稳定，如若不稳定，则需要走另外的消息处理异步逻辑兜底，做一个相对优雅的fix。如果代码层面没法优化的话，通过扩容服务则是最粗暴直接的解决方式。

最后，除了服务本身的指标之外，从业务角度而言也需要梳理业务的核心重要链路，补充打点metrics上报，从而在监控服务性质指标的同时，也可以及时发现一些业务性质的问题。业务错误最终会导致服务可用性下降，这样通过结合同时间段的指标聚合分析，服务SLI的下降问题就可能会更加容易被定位到。