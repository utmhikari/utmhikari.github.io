---
title: 【测试人生】SQL变更的问题拦截手段
date: 2023/07/08 14:03:51
categories:
- 测试人生
tags:
- 数据库
- SQL
- MySQL
- DevOps
- 变更管控
---

在DB做变更发布的各类场景当中，通过SQL更改DB数据内容，是最为常见的场景。既然是最为常见的场景，那么可能产生线上问题的概率也就越大。本篇文章就来探讨一下，要尽量减少SQL发布产生线上问题的可能性，需要采取什么样的手段。

首先是针对SQL语句本身而言，需要做积累检查。假设用的是MySQL，那么SQL类型大体可能分为以下几种：

- 新增类：CREATE表/列/索引、INSERT数据
- 更改类：UPDATE数据
- 删除类：DELETE数据、DROP表/列/索引（包含替换场景）、TRUNCATE
  
针对这些SQL类型，其产生线上风险的概率也不尽相同，需要分别进行治理。

<!-- more -->

针对删除类SQL，本身就需要直接拦截告警。从变更管控的视角，删除类的变更建议需要二次确认目的以及回滚的方式。针对DELETE数据的操作一般不推荐，从业务视角来看，通过软删除的方式一般相对更加合理，一来回滚方便，二来不会破坏自增主键的连续性；针对DROP类，需要确认删除的表、列、索引是否在用，是否有上下级依赖。如果存在的话，需要确认依赖是否在用，防止业务逻辑不可用的情况。

针对UPDATE类操作，由于容易回滚，建议二次确认回滚SQL。此外，UPDATE的扫描行数和影响行数不宜过长，通过EXPLAIN的方式，可以直到UPDATE操作具体用到了哪个索引，扫描行数和影响行数是多少。如果扫描行数/影响行数过高，势必会引起慢查询的问题；而如果更新量级不高的情况下，影响行数比扫描行数低很多，也需要确认下是否有误圈选数据的问题。针对后者，如果DB集群是master写slave读的情况下，建议先SELECT圈选出数据，统计主键，再依照主键做正式UPDATE发布。

针对CREATE/INSERT类操作，这类操作风险相对于UPDATE/DELETE较低，但也有一些需要注意的点。INSERT类操作，需要确认未被声明字段的默认值具体的业务含义，如果存在业务含义，需要确认是否符合预期；CREATE类操作，针对表主要确认索引、列是否加全，针对索引主要确认是否存在重复前缀导致冗余的情况。

然后是针对DB本身而言。DB的性能监控，包括请求延时、QPS、主从同步延时、慢查等内容，以及上下游服务的性能监控，业务对账，都需要确保完整可用。这里尤其针对DDL类操作，如果是对大表的索引/列做新增或删改，容易导致同步延时，进而导致DB性能出现开销，或者业务不可用。因此这种情况，建议需要在非高峰期操作，减小变更的影响面。

整体来看，SQL发布是业务变更中比较频繁的一部分。要做到拦截问题，减少线上问题影响面，上述的策略可以做一个总体参考。