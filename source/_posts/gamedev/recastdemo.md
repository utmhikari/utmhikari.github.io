---
title: 【游戏开发】初识寻路&navmesh，探索RecastDemo
date: 2021/08/07 21:35:28
categories:
- 游戏开发
tags:
- 寻路
- recast
- RecastDemo
- navmesh
- recastnavigation
---

在手游时代，尤其对于大世界游戏而言，寻路的实现基本在专门的寻路服务器上进行。在众多寻路的解决方案中，[recastnavigation](https://github.com/recastnavigation/recastnavigation)是最为经典实用的一个，很多游戏甚至游戏引擎都采用类似的实现。recastnavigation项目自带了RecastDemo，用图形化的界面帮助用户认识寻路网格（navmesh）的生成以及寻路的过程。因此，作为初学者的笔者，也决定通过RecastDemo去初步认识寻路的机理奥秘。

## 构建RecastDemo

首先克隆recastnavigation项目，从文档中可以看到RecastDemo的构建支持Windows、Linux、MacOS三端。从实际测试的效果来看，MacOS可能存在字体无法加载的问题，建议是用Windows跟Linux跑着玩。以Windows为例，首先需要下载[premake5](https://github.com/premake/premake-core/releases)以及[SDL开发库VC](https://www.libsdl.org/download-2.0.php)。premake5需要放到`PATH`下，而SDL开发库VC解压后需要按照文档描述，放到recastnavigation项目目录的`RecastDemo/Contrib`目录下，更名为`SDL`。

之后，在`RecastDemo`目录下执行`premake5 vs2019`，可以在`RecastDemo/Build/vs2019`中看到`recastnavigation.sln`项目文件。用VS2019打开，构建RecastDemo，就会生成exe在`RecastDemo/Bin`目录下。进入这个目录执行`RecastDemo.exe`，就能打开工具界面了。

## 基础寻路操作

<!-- more -->

打开软件，在右侧`Properties`选中`Sample`为`Solo Mesh`，`Input Mesh`为`nav_test.obj`，下拉点击`Build`，就能看到生成navmesh的结果

![main_panel](/uploads/gamedev/recastdemo/main_panel.png ''main_panel'')

在左侧的`Tools`栏下，点击`Test NavMesh`，然后在地表上用右键（shift+左键）以及左键分别标定起始位置和结束位置，就能够直接看到寻路路径生成的结果

![nav_result](/uploads/gamedev/recastdemo/nav_result.png ''nav_result'')

左侧的`Tools`栏里面，点选`Pathfind Straight`，可以看到寻路路径的点位连接，点选`Pathfind Sliced`，可以看到寻路查找的整个过程。

## 寻路参数调整

从先前的navmesh生成结果可以看到，在楼梯处没有生成寻路网格，所以如果用这么一个结果放到游戏里的话，玩家是不可能自动上楼的。

解决这个问题的方法，第一种是在`Properties`中，增加`Agent`的`Max Climb`，使得楼梯高度能够符合navmesh生成的标准。第二种是调整`Sample`为`Tile Mesh`，使得navmesh能够以一个地块tile为单位生成，地块与相邻地块之间也会计算连通性，从而使得寻路网格变成一个整体。在这个基础上，navmesh就会覆盖到每个台阶。之后，再使用跳点off-mesh连接每个台阶，使得台阶之间能够成为通路。

我们调整`Sample`为`Tile Mesh`，调小`Cell Size`和`Tile Size`，点击`Build`生成，再点选`NavMesh Portals`，就可以看到现在navmesh覆盖的范围以及不同tile之间的交界。

![tile_mesh](/uploads/gamedev/recastdemo/tile_mesh.png ''tile_mesh'')

在台阶之间加上off-mesh，可以在左边`Tools`选择`Create Off-Mesh Links`去加双向的link。加完之后测试寻路，就能看到上楼的路径了。

![off_mesh](/uploads/gamedev/recastdemo/off_mesh.png ''off_mesh'')

此外，还有一种常见的需要调整的参数，是地块的寻路成本，通常与地形的类型有关，比如在水里面，寻路的成本就高，在大路上，寻路的成本就低，并且有些时候，策划就希望玩家自动寻路能够优先去找有大路的路径。这个时候，可以通过`Convex Volumes`包裹/标识一些路面，在寻路的时候，这些路面相对于一般的路面，会有不同的成本计算规则。

在左侧的`Create Convex Volumes`选项中，我们可以创建一些包围盒，将特定的路面包裹住，标识这些路面的“地形”。比如下图的例子，我们在中间的小路标识了“Water”水体，最终寻路的结果，会从陆地绕道过去。

![convex_volume](/uploads/gamedev/recastdemo/convex_volume.png ''convex_volume'')

在demo的`NavMeshTesterTool.cpp`中，我们可以看到不同“地形”对应的寻路成本定义。实际游戏开发时，寻路成本也有自定义的必要。

```cpp
void NavMeshTesterTool::init(Sample* sample)
{
    m_sample = sample;
    m_navMesh = sample->getNavMesh();
    m_navQuery = sample->getNavMeshQuery();
    recalc();

    if (m_navQuery)
    {
        // Change costs.
        m_filter.setAreaCost(SAMPLE_POLYAREA_GROUND, 1.0f);
        m_filter.setAreaCost(SAMPLE_POLYAREA_WATER, 10.0f);
        m_filter.setAreaCost(SAMPLE_POLYAREA_ROAD, 1.0f);
        m_filter.setAreaCost(SAMPLE_POLYAREA_DOOR, 1.0f);
        m_filter.setAreaCost(SAMPLE_POLYAREA_GRASS, 2.0f);
        m_filter.setAreaCost(SAMPLE_POLYAREA_JUMP, 1.5f);
    }
    
    m_neighbourhoodRadius = sample->getAgentRadius() * 20.0f;
    m_randomRadius = sample->getAgentRadius() * 30.0f;
}
```

## 总结

初识RecastDemo，可以看到寻路网格生成和寻路逻辑是一个非常复杂的过程，并且也是一个需要逐渐优化的过程。寻路网格生成，不代表最终游戏里玩家自动寻路可以成功，不仅可能受到崎岖地形的困扰，动态阻挡、优先级体验等方面也是需要着重探索寻路问题的地方。

recast寻路相关的参考资料非常多，可以一一关注：

- [Recast基础](https://zhuanlan.zhihu.com/p/74537236)
- [Detour寻路](https://zhuanlan.zhihu.com/p/78873379)
- [Nav导航网格寻路](https://blog.csdn.net/ynnmnm/article/details/44833007)
- [recastnavigation开发者博客](http://digestingduck.blogspot.com/)
- etc
