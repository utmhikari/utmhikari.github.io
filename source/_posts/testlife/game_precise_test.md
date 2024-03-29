---
title: 【测试人生】游戏业务测试落地精准测试专项的一些思路
date: 2023/10/02 11:57:48
categories:
- 测试人生
tags:
- 游戏测试
- 精准测试
- 功能测试
- 专项测试
- 业务测试
---

精准测试在互联网领域有广泛的应用。以变更为出发点，通过对变更内容进行分析，可以确定单次变更具体涉及到哪些模块和功能点，以及是否存在夹带风险，从而从QA的视角，可以知道哪些功能模块需要做测试，以及哪些变更内容不符合预期。相比于互联网QA，游戏QA接入业务项目研发过程并没有那么深入，比如项目代码权限基本上游戏QA不会拥有，但即便如此，要在游戏测试领域应用精准测试专项技术，还是有一定思路可循。

因此，本篇文章，笔者以自身经验为出发点，讲述一下在游戏业务测试落地精准测试专项的一些思路。

<!-- more -->

首先来看，游戏业务测试场景，精准测试要分析什么以及测什么。精准测试一般会采用代码覆盖技术来分析单次变更所影响的范围，也包括分析变更对上下游服务跟DB的影响。但是，游戏服务架构相比于互联网微服务架构，上下游业务链路不会非常深。因此，从游戏测试角度，代码变更内容可以更加精确定位到具体哪个系统哪个功能点有所改动，理论上会更容易评估哪些测试点需要测试。

如果游戏QA不具有项目代码权限的话，那么可以退而求其次，可以从业务配置或者协议定义变更的角度，来推断哪些系统哪些模块需要做回归测试。虽然这类变更的信息粒度不及代码变更，不一定非常精准，但至少也可以发现夹带的变更风险。游戏本身作为一个微缩的世界模拟，各类玩法系统在实现上，逻辑耦合的可能性是很高的。因此，在日常迭代期间，如果能够确认更多的夹带风险，对于游戏大版本发布的质量防控是有所收益的。

然后来看，要在游戏业务测试场景落地精准测试，需要做些什么。从游戏业务测试视角，要把精准测试专项落起来的话，一期的待测系统选型是非常关键的。对于强客户端类型的系统玩法，比如时装（展示）、载具、枪械等，更重的逻辑会落在客户端用于仿真模拟的代码，或是Actor状态同步的代码，业务属性并不高，因此做变更分析会比较困难，并不适合做精准测试的初步推广。反之，类似副本任务、运营活动、成就收集、商城交易等类型的系统，一是代码更能体现业务属性，二是实现机制可能和其它系统玩法有所交集，因此比较适合做初步推广。

精准测试的整体落地方面，不建议做比较激进地做推动。这是因为，精准测试本身属于专项范畴，从实操角度，会存在额外的工作量，并不能完全替代日常地功能测试工作。因此，推荐仅圈定特定范围做整体落地，方式比如：对于整个项目测试组，以双周或者月为周期做一轮变更扫描，下发到各系统owner做变更内容确认；仅针对特定系统模块的测试小组，单独做变更对应测试点的标注，以及实时监控变更内容，做更细粒度更日常的精准测试。目标收益层面，都可以通过【专项发现Bug数】这一指标来衡量，这是因为，项目日常迭代期间，由Bug数可以直接反映精准测试所能发现的问题。

最后，需要强调的是，精准测试本身也是游戏业务测试锦上添花的一部分。从宏观的角度看，精准测试可以发现夹带风险，可以通过精准定位测试点提升测试能效，但专项落地本身也会耗费一定的时间人力，以及理解专项知识跟目的的成本。从游戏项目整体质量保障角度看，具体是否要投入做精准测试，收益能否达到预期，还需要谨慎斟酌决策。
