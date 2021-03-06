---
title: 【测试人生】游戏策划表格检查工具的一种解决方案
date: 2021/03/06 18:20:02
categories:
- 测试人生
tags:
- 游戏测试
- 表格检查
- 测试开发
- mongodb
- 工具开发
---

策划表格数据检查是游戏测试工作的刚性需求。在游戏开发期中，有大量bug的起因是策划同学在配置上不够规范到位。因此作为测试角度而言，需要更加便捷、更加精准的方法去定位到策划表格配置的问题。除了依靠业务人员自身对业务的熟悉程度之外，也更加依赖于一个强大有力的工具，辅助表格数据检查。

表格数据检查的目的有以下一些：给定某个数值策划案，检查实际配置与策划案是否有出入；给定某个配置规则，检查实际配置是否有不符合规则，造成风险的地方（除去程序导表检查的那一部分）。针对这些需求，简单粗暴的方法就是强行coding的方式，将读取表格（Excel）数据出来（或者将表格数据转化为程序文件），然后用编码的方式联表，继而通过coding逻辑，去导出不符合规则的数据。这一种方式虽然灵活，但对于业务侧同学，还存在壁垒以及需要突破的地方：

- 壁垒：业务侧同学的技术能力，通常难以hold住coding的技巧。从技术人员角度而言，涵盖大量代码的臃肿的表格检查规则，可读性很差且难以维护。
- 突破：相较于人肉检查表格数据而言，时间的消耗主要在“联表”这一操作上面。游戏内部逻辑相对复杂，策划表之间的数据也是紧密耦合，比如一个宝箱抽取，就有可能涉及4~5个表的相互关系。如果不能够解决联表耗时的问题，表格数据检查的效率会大打折扣。

因此总体来看，除了采用coding这一备选方案之外，另外一个较好的方法是采用声明式、配置化的方式描述表格检查规则，通过一系列数据处理规则的串联，导出来一份最终数据。这样一来相对减少了学习成本，从业务侧角度而言，从“学习coding”变成了“理解配置”；二来解决了联表效率的问题，业务侧只需要描述一个联表的数据处理规则，后台就可以自动按照规则描述的方式对数据处理，最终呈现到业务的，直截了当，就是最终的结果；三来解决了根本目的，不论是策划案比对（通常是另外的文档，不能按版本diff）还是检索不合规的数据，本质上都是数据导出，因此用数据处理规则的串联，就能解决大部分的需求。

<!-- more -->

了解mongodb的同学，多多少少都会听说到[mongodb聚合](https://docs.mongodb.com/manual/core/aggregation-pipeline/)，亦即数据处理流水线。在mongodb中，如果需要实现复杂的数据查询需求，就需要用到聚合的方式，定义多个流水线规则，比如过滤查询、排序、group、lookup、字段值转化、字段值计算等，去呈现最终的数据形式。这种数据查询的实现方式，与表格检查的需求不谋而合，因此笔者在实践中，也果断借鉴mongodb的思路，实现了导表、联表、转化字段、列表展开等多种数据处理规则，并且研发了Web前端界面方便实现简单的配置。这样一来，业务测试同学也只需要按照给定的规则配置方法，配置流水线规则，就能获得最终想要的数据。

现在剩下的问题是，原生的表格数据从何而来？如何管理？针对这点还是需要从用户的角度出发。用户侧所关心的内容无非只有这么几个：我用什么样的导表规则，需要在什么版本的策划表，导出什么样的数据。因此，当用户提交到表规则与策划表版本的之后，程序后台就需要自动执行相应的行为：更新表格到对应的版本->通过脚本去Archive表格数据为特定的数据结构->通过一系列数据处理规则加工数据->将数据转化为用户友好的形式呈现。在笔者的方案中，做了这么几件事情去解决这些问题：

- 实现一套策划数据仓库管理系统，管理同时存在的多个策划表仓库，具体形式和笔者实现的[repomaster](https://github.com/utmhikari/repomaster)类似，仓库的元数据存在内存/缓存中，并且支持加载自定义导出数据脚本的方式导出策划配置数据。数据仓库管理模块需要与数据处理模块分离，尤其是仓库过大，每次更新仓库会占用较多资源，不分离的话会影响数据处理的进程。数据仓库管理与数据处理模块，通过共享代码/协议的方式，减少代码管理的成本。
- 在策划数据处理和数据仓库管理系统中，分别实现一套简易的事务管理系统。针对每一个用户的导表请求，数据处理模块生成一个后台事务单独处理。如果需要更新数据，就发送请求数据仓库管理模块更新数据，数据仓库管理模块也相应地生成一个后台事务，随机选择一个仓库更新/导出数据，并通知数据处理侧拿取导出的数据来处理。这一过程中，就算出现单点故障/数据未成功获取等意外情况，也是可以接受的。从经验上看，大量的时间瓶颈主要集中在更新仓库这一过程上。

实现了这些，基本上一个表格检查工具就成型了。当然，表格检查除了这些需求之外，还有类似不同版本表格diff、gitlog追踪一类的需求。因此这一块的业务，待挖掘的空间是非常丰富的。
