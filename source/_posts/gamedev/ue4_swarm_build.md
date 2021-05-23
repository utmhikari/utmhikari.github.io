---
title: 【游戏开发】UE4联机渲染swarm agent配置
date: 2021/05/23 14:18:15
categories:
- 游戏开发
tags:
- UE4
- swarm agent
- 联机渲染
- 游戏开发
- 分布式构建
---

UE4在构建场景光照时，会启动`swarm agent`进行构建，但如果只用一台电脑会出现构建速度较慢的情况。为了加快编译的效率，需要配置联机渲染。

首先需要注意的是，在UE4中自动打开`swarm agent`和手动打开`swarm agent`会用到不同的配置。因此，建议的方法是手动打开`swarm agent`进行配置（对于所有机器），然后再开UE4。每个`swarm agent`以及调度器`swarm coordinator`的可执行文件位置，都在引擎的`Engine\Binaries\DotNET`下

在官方文档中，有`Unreal Swarm`配置的[例子](https://docs.unrealengine.com/en-US/RenderingAndGraphics/Lightmass/UnrealSwarmOverview/index.html)可以参考。假设你有一台性能强劲的机子，和一台你日常工作但性能一般般的机子。这样可以如下配置：

<!-- more -->

1、两台机子都必须装UE4（最好同一版本），都会自带`swarm agent`。两台机子局域网互通（Windows的话，开启网络共享），用主机名就可以访问对方。

2、**将性能强劲的机子作为主机**。在性能强劲的机子上，打开调度器`swarm coordinator`以及`swarm agent`，然后在`Settings -> Distribution Settings`如下配置：

![主机Agent](/uploads/gamedev/ue4_swarm_agent/master_agent.png ''主机Agent'')

配置项意义如下：

- `AgentGroupName`：agent所属的组
- `AllowedRemoteAgentGroup`：哪些组的agent可以接收自己下发的任务
- `AllowedRemoteAgentNames`：哪些匹配名字的agent可以接收自己下发的任务
- `AvoidLocalExecution`：避免本地执行，优先分发任务到其它Agent。如果任务里某些步骤只能只能本地执行，实测选择`true`不会跑满核，而选择`false`会跑满。
- `CoordinatorRemotingHost`：调度器Host（主机名/域名/IP）
- `EnableStandaloneMode`：启用独立模式（不下发/接收构建任务）

对于主机而言，`AgentGroupName`和`AllowedRemoteAgentGroup`可以设置成一样的值`UE4Render`，表示主机属于`UE4Render`组，并且从主机下发任务到自己；`AllowedRemoteAgentNames`填写通配符`*`表示允许所有机子；`AvoidLocalExecution`填写默认`false`即可；`CoordinatorRemotingHost`填写主机自己在局域网上的名字（保证稳定连上自己即可）；`EnableStandaloneMode`填写`false`

填写完成之后，在主机的`swarm agent`上点击`Network -> Ping Coordinator`，可以在调度器上看到主机的`swarm agent`

之后需要设置主机`swarm agent`的性能参数。在`Settings -> Developer Settings`下，将`ShowDevelopMenu`选择为`true`，就能看到`DeveloperSettings`页签。选中该页签，在`Local Performance Settings`下，设置`LocalJobsDefaultProcessPriority`和`RemoteJobsDefaultProcessPriority`为`AboveNormal`（最高优先级），然后将`LocalJobsDefaultProcessorCount`和`RemoteJobsDefaultProcessorCount`设置为`<=主机逻辑处理器数-2`的值（不然可能用主机的人会卡死）。这样就能保证局域网内其他机子发起任务，主机可以出力了。

然后设置工作机的`swarm agent`，配置样例如下：

![工作机Agent](/uploads/gamedev/ue4_swarm_agent/worker_agent.png ''工作机Agent'')

工作机和主机的`swarm agent`配置基本相同。工作机上，`AgentGroupName`和`AllowedRemoteAgentGroup`设置成为跟主机一样的值`UE4Render`；`AllowedRemoteAgentNames`填写通配符，允许任务下发到所有机子；`AvoidLocalExecution`可填写`true`，如果机子非常差的话，否则感觉工作机可以出力的话，就填写`false`，然后打开`DeveloperSettings`，将`LocalJobsDefaultProcessorCount`和`RemoteJobsDefaultProcessorCount`设置为`<=工作机逻辑处理器数-2`的值，保证工作机在跑满一定核数的情况下，机子不会负载太高（这也是自己现在的设置）；`CoordinatorRemotingHost`填写局域网里主机的名称（最好不要填写IP，如果是自动分发的话）；`EnableStandaloneMode`填写`false`。工作机的`DeveloperSettings`下，和执行优先级相关的配置项可以保持和默认一样。

这样整个小集群就搭建完成了，可以在两台机子的`swarm agent`里，通过`Network`选项下的`Ping Coordinator`和`Ping Remote Agents`检查agent和调度器以及其它agent的连通性，相关信息会在`Log`日志页签显示。配置完`swarm agent`，工作机打开UE4，点击`Build`构建光照，就能够看到分布式构建的效果了。
