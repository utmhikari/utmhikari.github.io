---
title: 【GitHub探索】新款命令行工具terminus测试
date: 2019/06/22 22:45:17
categories:
- GitHub探索
tags:
- terminus
- 效率工具
- terminal
- shell
- 测试
---

## 前言

六月的Github趋势榜单上，除去一些文书、教程性质的项目外，大部分项目并非自己所针对的领域。因此，果断试水了一款软件，

Windows系统下的命令行工具配置，一直是开发者们纠结的痛点。在这一块，[cmder](https://cmder.net/)、[MobaXTerm](https://mobaxterm.mobatek.net/)甚至即将上线的[Windows Terminal](https://github.com/microsoft/terminal)，都是不错的解决方案。

而今天介绍的这一款软件——[terminus](https://github.com/Eugeny/terminus)，在六月份跻身趋势排行前十，则似乎更加符合我们对命令行工具的影响。作为一个终端模拟器，terminus采用Angular + Electron开发，包含了终端模拟器必备的许多功能，兼具美观与实用性。我们可以首先来看看，terminus的界面长什么样子~

<!-- more -->

![terminus界面](/uploads/githubdiscovery/terminus/main.PNG)

下面，让我们一起试水一下terminus吧~

## terminus特性

以最新（1.0.82）的Windows版为例，terminus包含的特性如下：

- 多标签终端支持（cmd、powershell、bash）以及额外终端配置
- 多皮肤/主题配色定制（嵌入终端皮肤数十种）
- SSH支持与管理
- 插件、快捷键、右键菜单支持

从功能的覆盖度来讲，作为一个轻量级的终端程序来说，满足多标签、右键菜单以及SSH，已经非常棒了。

## terminus测试

作为一个测试人员，测试一个没有策划文档的成品时，可以遵循以下的测试思路：

- 从普通用户角度而言，最基本的操作是否能够顺利跑通？
- 从DIY用户角度而言，各种与配置关联的用例操作是否也能顺利？
- 猜测产品设计的亮点之处，这些亮点之处的操作用例是否能够跑顺利？

以及以下的测试策略：

- 测试尽量关注恶性bug，亦即那些显著影响或阻塞用户的软件操作的bug
- 不刻意关心bug的成因，但要为开发提供足够的信息帮助他们定位bug

遵循上述思路与策略，按照测试bug提单的标准，小列自家Windows下1.0.82版本几个测到的恶性bug：

### 应用设置界面下无法新建终端/SSH连接

- 缺陷描述：仅当设置界面的Application栏下，新建terminal后不显示终端，并且无法连接SSH
- 复现过程：点击“设置”按钮进入Application栏，再点击新建终端或SSH按钮均不显示界面，且终端标签页无法关闭
- 备注信息：切换其它设置项或其它标签页后，阻塞的新建终端/连接SSH操作可以继续
- 错误输出：angular module有从undefined读取appVersion属性的行为
- 图片描述：见下= =

![从设置新建终端不显示](/uploads/githubdiscovery/terminus/main.PNG)

### 无法再次打开terminus

- 缺陷描述：当terminus为开启状态时，无法再次打开terminus
- 复现过程：开启一个terminus程序后，再次打开terminus，原有的terminus关闭，新的程序不开启
- 备注：原有terminus关闭后，再次打开terminus，原先开启的标签依然存在

### 切回插件设置界面下拉栏不显示

- 缺陷描述：当有其余终端标签情况下，插件设置页面显示默认插件搜索结果后，切终端再切回，下拉栏不显示
- 复现过程：首先新建终端，而后新建插件设置标签等待异步插件搜索操作完成，再点击终端标签，再回来点击插件设置标签
- 备注：需要再一次开启插件设置标签，才可以显示下拉栏
- 图片描述：见下= =

![切回插件设置界面下拉栏不显示](/uploads/githubdiscovery/terminus/plugin.PNG)

## 总结

从开发的角度而言，先确定需求，写模版，后面出了具体bug再迭代，是一个妥善的路子。

从试水结果看来，terminus为我们开发命令行工具开辟了更加精致的思路，作为一个轻量级的软件，从功能的完备性而言，已经能够具备日常使用性。

虽然有些恶性bug，并且也有些GUI渲染上的瑕疵，但并不妨碍整个研发的大方向，因此我们期望开发人员能够后面抽空一个个补正。

故现在这个时段，没有用过terminus的同学们，可以试用一下啦~如果觉得不顺手，也请给予一点耐心——期待terminus后续的版本吧！
