---
title: 【测试人生】游戏策划表格测试工具的技术实现
date: 2021/06/01 23:40:57
categories:
- 测试人生
tags:
- 游戏测试
- 表格检查
- 测试开发
- 表格测试
- 系统设计
---

在先前的[《游戏策划表格检查工具的一种设计》](https://utmhikari.top/2021/03/06/testlife/table_check/)一文中，笔者分享了在一般游戏测试业务背景下设计策划表格检查工具的一种方式。本文基于先前文章的内容，将原先的表格检查工具升级为表格测试工具，涵盖更多的内容，并对其中部分技术实现进行分享。

## 测试工具架构设计

整个测试工具分为两个部分：

- 仓库管理服务：负责管理多个策划表格的svn/git仓库，并涵盖导入表格数据的功能
- 表格测试服务：负责接收用户的测试请求，向仓库管理服务请求特定版本的数据，执行表格测试任务

测试工具的整体架构如下图：

<!-- more -->

![表格测试工具](/uploads/testlife/table_test_tool/table_test_tool.png ''表格测试工具'')

仓库管理服务需要挂载一个大空间的硬盘，硬盘里存储多个策划表格仓库，而管理服务则缓存仓库信息在redis中。同时用户可以在仓库管理服务的目录下自定义导入数据到redis的脚本，仓库管理服务运行时动态执行脚本代码，将表格数据以及其元数据导入到redis

策划表格测试服务连接redis，但约定上只有读的权限，没有增删的权限，且只能读取redis中缓存的表格数据及元数据。表格测试服务将测试相关的配置以及结果则都存储在mongodb中，提供服务接口给到web前端

设计仓库管理服务，如果用python的话，可以用`ProcessPoolExecutor`先开一组worker，每个worker在接收到任务时，再在其中开另外的`ProcessPoolExecutor`执行任务（像表格对比就需要同时更新并上传两个表的数据，因此得另外开pool去submit任务），在任务执行完后销毁每个worker里的pool。这样能够有效解决内存泄露的问题

## 表格检查

在先前的文章当中，提到表格检查的本质其实是数据导出，可以用mongodb聚合的方式去实现数据导出。

mongodb的聚合是由一系列的stages组合而成的，每个stage有固定的语法描述数据处理的方式。而放到表格数据导出这个需求里，我们可以拟定一套数据处理流水线：

- 数据容器：从redis中读取某个版本的表格数据，转化成一个数据容器`DataContainer`的结构
- 初始数据：从数据容器中，筛选需要的数据作为初始数据，合并为一个`List[Dict[str, Any]]`形式的数据
- 数据处理步骤集：通过一系列数据处理步骤，将初始数据转化成包含最终需要的数据的集合
  - 每个数据处理步骤的接口定义是`process(data: List[Dict[str, Any]], container: DataContainer, tracer: PipelineStageTracer) -> List[Dict[str, Any]]`，其中`data`是上一个处理步骤下来的数据，`container`是数据容器源头，`tracer`则用于跟踪当前处理步骤的信息
- 数据提取规则：根据最终处理的数据，再次提取需要的数据出来，标注每个字段的含义。这一步主要用于人性化展示数据导出结果

数据处理步骤需要实现json配置->处理步骤数据结构的转化。根据mongodb的定义，首先需要拆解这些步骤包含的元素：

一些基础的表达式包括：

- 定位符`Locator`：xx.yy.zz，用来标识数据在某个object的位置
- 计算符`Calculator`：用于执行数学计算，参考[aggregation expressions](https://docs.mongodb.com/manual/meta/aggregation-quick-reference/#aggregation-expressions)中的`arithemtic expr operators`部分
- 累积符`Accumulator`：用于提取某个列表数据的属性，参考[mongodb group](https://docs.mongodb.com/manual/reference/operator/aggregation/group/)的内容

一些基础的处理步骤包括：

- 过滤`FilterStage`： 可以参照mongodb的[查询实现]( https://docs.mongodb.com/manual/reference/operator/query/)
  - 需要的基本数据包括：定位符`Locator`、运算符`Operator`、计算值`Value`。根据不同的`Operator`去解析不同的`Value`。比如如果需要进行逻辑运算，可以让`Value`变成内嵌`FilterStage`的列表
- 联表`LookupStage`：可以参照mongodb的[lookup实现](https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/)
  - 需要的基本数据包括：另一条流水线的定义`Pipeline`、自己流水线和另外流水线的`Locator`以及运算符`Operator`、流水线联入到的字段`Alias`
  - 可以根据lookup的实现自由添加stage的属性，比如保留不匹配的结果：`PreserveNullResults`
- 列表展开`FlattenStage`：展开特定定位符下的列表值，每一行包含列表的一个元素（1->n）的转换
  - 主要用于最终人性化地在表格中展示数据
- 字段遴选`PickStage`：只保留特定的字段值到下一轮，通常用于内存优化

每个stage都需要实现前面说的数据接口`process`。如果有特殊的数据检查需求，可以根据这些基础stage的定义方式去自创一些，实测用python创建一个新的stage，可能不需要100行。

有了这些基础，就能够以配置化的方式去实现数据检查规则。

## 表格对比

在[《为游戏策划与QA量身定制的excel表diff算法》](https://utmhikari.top/2020/01/23/testlife/excel_diff/)一文中已详尽叙述excel-diff的算法，本文在此基础上，提出一些tips：

- 导入数据需要对excel做二次处理。建议去掉空表头的数据，否则会冗余较多内容
- excel-diff算法方面，对行进行相似度比较是较为关键的一步，能够显著减少diff的时间。通常来讲，每行的前5列数据相对较为重要，从人类角度而言也通常通过前几列数据去区分哪些行做了改动。因此在相似度计算方面，前5列需要赋予高权重，如果匹配就加权重，不匹配则反减权重；而其他列则匹配加权重，不匹配不加权重。
- 前端如果用vue做的话，有些坑可以参考[《用vxe-table展示excel-diff的结果》](https://utmhikari.top/2021/05/01/geekdaily/excel_diff_vxe-table/)一文

## 查询功能

基于上面所提到的`DataContainer`，我们可以根据这个数据结构的特性设计一系列查询接口。这些都是比较简单方便实现的内容

- 通过某个名字，搜对应的ID
- 输入一系列ID，输出一系列名字
- 输入一个宝箱ID，输出宝箱抽取的Mindmap
- etc

## 总结

在数据管理+服务的架构设计基础上，可以实现多种多样的测试需求。并且从通用性角度来讲，每个项目都可以遵循以这个技术规范去扩展表格测试工具的实现，初期的话只需要修改数据导入redis的脚本就能够开始用上工具。接入上理应不会有太多障碍，同时也能把这个技术思路及产出给沉淀下来。

美中不足的地方，当前的工具实现还未考虑git/svn hook及时获取表格变更的diff，以及用git/svn的API获取更多仓库的信息。这些都是有挖掘价值的内容。
