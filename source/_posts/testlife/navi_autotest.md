---
title: 【测试人生】UE4大世界游戏寻路效果自动化测试
date: 2022/11/20 12:42:33
categories:
- 测试人生
tags:
- 游戏测试
- 寻路
- UE4
- recast
- 自动化测试
---

在一些无缝大世界的游戏当中，我们通常能够体验到游戏的自动寻路功能，通过自动寻路，玩家可以不用任何操作就到达任务或者玩法的目的地，从而让游戏过程更加轻松。在测试寻路功能时，不仅需要检查寻路是否成功到达，而且也需要关注寻路路径呈现的效果，从而确定玩家是否走在策划预想的路径上。

由于寻路起点、终点选择的随机性，人工执行寻路测试时，往往需要根据自定义的规则遍历多个特定的起点终点，这样操作起来不仅非常耗费人力，而且针对再后台存储`navmesh`数据、做动态烘焙以及计算寻路路径的场景，在验收寻路效果时，测试人员还需要多次手动从后台拉取一定范围的`navmesh`数据并绘制在客户端的路面上，才能知道玩家是走在什么样的路面。为了解决寻路效果测试的效率问题，引入自动化技术显得非常有必要。

因此，笔者将结合自己实际的工作经验，分享一种在`UE4`大世界游戏中，寻路效果自动化测试的方案。

<!-- more -->

`UE4`默认采用`Recast&Detour`的方式实现寻路。通俗来讲，`Recast`是一种在3D世界生成2D寻路网格面`navmesh`的方案，使得寻路的问题转化为在一个网格面上的一个格子到另一个格子的路径计算问题，而`Detour`则是根据寻路网格计算寻路路径的方法。

有兴趣的读者，可以查阅相关资料：

- [recastnavigation-github](https://github.com/recastnavigation/recastnavigation)
- [初识RecastDemo](https://utmhikari.top/2021/08/07/gamedev/recastdemo/)

3D世界中包含不同的地形，比如山地、水体、公路等，如果忽略这些地形信息，那么计算出来的寻路路径，效果就可能趋于一条直线。如果玩家真按照这样的路径行走的话，很可能会出现走到水里或者障碍物的情况，导致实际会没有走到一个最符合现实的路径方案。

为了解决这个问题，在`UE4`编辑器中，也支持通过不同类型的`NavModifierVolume`标记网格路面，从而使得每个路面在实际寻路计算中，具备不同的经过成本`cost`。

有兴趣的读者，可以查看官方文档的资料，详细了解：

- [Navigation System](https://docs.unrealengine.com/5.1/en-US/navigation-system-in-unreal-engine/)
- [Navigation Components](https://docs.unrealengine.com/5.1/en-US/navigation-components-in-unreal-engine/)

充分了解了这些内容，再结合下自己项目实际的情况，就能着手实现寻路效果自动化测试了。假设游戏是采用后台寻路的方案，整个自动化测试的流程可以这样做：

首先，我们需要预先准备`NavModifierVolume`配置数据，通过这些数据，才能判断玩家行走在怎样的路面上。同时，也要准备一系列测试用例，包含寻路的起点终点、期望时间和路面占比等等，整个自动化的流程需要遍历这些内容。

然后，需要一套自动化驱动寻路的流程，并且需要在寻路过程中，以特定的频率收集玩家所经过的路径点。这样，每一次寻路我们都能够得到玩家的路径点集，从而能够反映玩家的寻路效果。

对于每个路径点，需要求得这些点对应的是怎样的路面，这时候就需要用到预先准备的`NavModifierVolume`配置数据了。这个计算过程实质上是求在3D空间内，一个点是否在一个长方体内。由于每个`NavModifierVolume`导出的`transform`数据中，包含位置、旋转以及长宽高数据，因此可以参考[这篇文章](https://utmhikari.top/2021/09/01/gamedev/ue4_point_in_cuboid/)，进行计算判断。

最终，整个自动化测试过程完成后，我们就可以得到这样一些数据：

- 结果汇总：每个起点终点的寻路测试结果以及所有路径点跟路径点所对应的路面
- 是否通过指标：寻路是否成功、寻路时长是否符合预期、寻路路径占比是否符合预期

通过表格或者3D散点图对结果进行可视化处理，就可以得到一份更加清晰的寻路测试报告。通过报告，我们可能可以排查出这样的问题：

- 寻路路面配置缺失或不对，或因为寻路路面配置变化导致寻路效果相较以前有较大差别
- 因副本切换等原因重新生成阻挡物件，或者`navmesh`生成效果与实际物件摆放有出入，导致寻路实际阻塞