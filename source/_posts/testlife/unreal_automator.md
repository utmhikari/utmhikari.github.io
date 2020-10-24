---
title: 【测试人生】UE4游戏自动化测试插件——UnrealAutomator
date: 2020/10/24 15:09:23
categories:
- 测试人生
tags:
- 游戏测试
- UE4
- UnrealAutomator
- 游戏自动化
- UE4插件
---

UE4游戏/手游自动化测试有很多方案可以执行，不论是传统的UI测试方法还是具备前瞻性质的以图像识别+机器学习技术为主的方法，都能够满足不同的需求。适逢1024节日，受到[GAutomator](https://github.com/Tencent/GAutomator)和[PocoSDK](https://github.com/AirtestProject/Poco-SDK)的启发，笔者近期决定开始UE4专属自动化测试插件[UnrealAutomator](https://github.com/utmhikari/UnrealAutomator)的研发。当前已经集成并扩展了GAutomator的UI信息检索功能，已经能够满足UI测试服务端的基本需求。

UnrealAutomator的核心愿景，是希望集成游戏QA同学日常测试需求相关的功能到统一的插件当中，并在稳定的通信协议基础上设计易于扩展/二次开发的SDK，让各个UE4手游测试组能够比较容易地根据自己的需求去进行定制。相比较原有在UE4上的解决方案，PocoSDK的UE4插件并不能够像GA一样，通过AndroidWindow获得安卓手游的控件的精确位置；而GAutomator的UE4仅仅是集成了UI检索的功能，剩余的功能都需要GAutomator Python Client Module实现，且由于GA Client Module直接在代码实现中耦合了UIAutomator跟WeTest的相关功能，二次开发极其不方便。因此，UnrealAutomator将采取如下的方案解决这些问题：

<!-- more -->

- 采用HTTP协议，以[UnrealHttpServer](https://github.com/utmhikari/UnrealHttpServer)为基础扩展插件。其带来的收益是提供了稳定的通信协议，并且能有扩展到很多集成平台的机会，并且从代码review的角度上来考虑的话，采用Handler/Service/Model的机制，各个功能模块发挥的作用也会非常清晰，代码也比较容易读懂。
- 丰富检索功能与返回的检索信息，并增加了invoke event的功能，使得某些控件的事件（比如Button的OnClick）能够直接执行，减少一些操作上的不便。
- 丰富API的功能与实现，尽量使得外部的Client Module不需要考虑底层的基础，只需要考虑业务上的模块：
  - UnrealHttpServer的API Client，只负责与插件的对接
  - 移动端操作模块：adb client，UIAutomator
  - 第三方平台的agent
  - 自动化业务层逻辑抽象，比如登录、背包、组队等等游戏系统模块，抽象相关操作为http request
  - 自动化流程逻辑

UnrealAutomator除了UI相关功能之外，在现在的计划（脑补）当中，也希望集成更多的功能，使得能从游戏的底层挖掘更多深层次的信息，利于测试工作的验收与检查。

- 脚本语言框架支持，如Unlua、slua-unreal等
- 蓝图（物件模板）与游戏场景相关的功能挖掘
- 地图/Gameplay基本信息的支持
- Profiling相关的数据导出
- 抽象inputs、axis与行为树相关功能，实现角色操作与托管
- etc

先前不是C++/UE4程序员，借着UnrealAutomator这个机会，也希望锤炼一下这块的技术。一方面希望能够对手游技术栈有更加深入的理解，从而利于测试工作；另一方面也希望抛砖引玉，为手游QA工作输出一点微薄的贡献；再一方面也希望自己在业务百忙之中，能够坚持下来作品的创造，得到更为长足的成长~
