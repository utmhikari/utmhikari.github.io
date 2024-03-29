---
title: 【极客日常】慢查询的风险治理思路
date: 2024/01/07 16:30:08
categories:
- 极客日常
tags:
- 变更风险
- SQL
- 慢查询
- 数据库
- 后端开发
---

在线上环境运维过程中，我们通常需要治理慢查询的风险。慢查询会引起DB性能问题，并且当线上环境流量较大的情况下，就会出现因大量慢查询堆积导致DB被打挂的情况。因此，本篇文章分享一下慢查询的风险治理思路。

首先，我们需要知道什么情况下会出现慢查询。通常对于大表，未正确引用索引导致全表扫描，就会出现慢查询。慢查询出现也会经历从无到有的过程，而为何从无到有，就涉及到业务变更。以下几种业务变更场景就有可能导致慢查询的产生：

<!-- more -->

- 业务代码变更：代码逻辑没有正确引用索引
- DML变更：WHERE条件没有正确引用索引
- DDL索引变更：线上代码还引用原来的索引，导致实际索引未引用正确

慢查询的特征，从业务视角是DB响应速度变慢，而从DB视角是性能占用变大。从事后排查的角度，以MySQL为例，当变更后疑似发生慢查询时，我们可以结合[Slow Query Log](https://dev.mysql.com/doc/refman/8.0/en/slow-query-log.html)与[mysqldumpslow](https://dev.mysql.com/doc/refman/8.0/en/mysqldumpslow.html)来查看具体是哪些查询语句出现了慢查询。

之后，我们才需要针对可能出现慢查询的场景，设定预防的手段，尽可能避免事后止损。针对上述几种变更风险，我们可以各个击破：

- 业务代码变更：代码引用DB扫描、线下查询治理
- DML变更：EXPLAIN
- DDL索引变更：代码引用DB扫描、线下查询治理

DML变更的情况比较好解。我们可以通过[EXPLAIN](https://dev.mysql.com/doc/refman/8.0/en/explain.html)的手段解析DML（查询逻辑）预期会使用到的索引、扫描行数和影响行数。如果查询的是大表，并且没有引用索引，或者扫描/影响行数过高，则需要注意真实执行时候，可能会造成慢查影响。

业务代码或DDL索引变更的情况，则需要把变更内容扫描和线下治理关联上，来确定当次变更是否有风险。在业务代码线下测试的过程中，我们可以通过比如提取ORM-Log的方式解析一些先下代码生成的SQL，然后放到线上库EXPLAIN，从而发现线下变更可能导致线上慢查的一些case。在代码变更发布到线上的时候，一方面可以通过分析代码引用来判断代码是否正确引用索引，另一方面也可以再次确认线下发现的SQL风险是否已经确认修复，从而避免风险夹带到线上。DDL索引变更同理，在执行DDL前，也可以通过血缘关系找到上游的服务，根据服务代码历史的分析结果以及线下提取SQL的记录，来判断变更后会否出现索引未正确引用的情况。
