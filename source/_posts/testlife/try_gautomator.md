---
title: 【测试人生】游戏自动化工具GAutomator上手
date: 2020/05/05 14:40:35
categories:
- 测试人生
tags:
- 游戏测试
- 自动化
- GAutomator
- Unreal
- UIAutomator
---

最近开始研究一些游戏自动化测试方面的内容。游戏自动化测试是游戏测试研究领域的难点之一，当前主流的方案有两种，一种是采用纯粹的UI识别方法进行，典型的例子是[Airtest](https://github.com/AirtestProject/Airtest)，另一种是直接嵌入到游戏引擎中获取节点树等元素从而对实体进行操作，典型的例子是[GAutomator](https://github.com/Tencent/GAutomator)。由于笔者先前略微接触过Airtest方面的内容，因此本次决定上手GAutomator尝试游戏自动化。

本次上手过程具体则用GAutomator对Unreal4.24示例mobile项目中的元素进行操作，利用安卓手机进行调试。基本原理上，GAutomator会作为插件嵌入到Unreal项目中，自己包含一些获取World中信息的功能，而后listen一个端口，从而外部请求该插件可以获取World中的信息。通过adb进行搭桥，在外部，用户可以基于[GAutomatorAndroid](https://github.com/Tencent/GAutomator/tree/master/GAutomatorAndroid)编写，从而不仅可以与GAutomator的Unreal插件打通，而且也可以通过预先集成的[UIAutomator](https://github.com/xiaocong/uiautomator)这样的工具直接模拟屏幕操作。

<!-- more -->

由于GitHub上的GAutomator项目针对Unreal只支持简单的UMG支持，因此笔者也将Unreal插件单独fork到[GAutomatorUnrealSDK](https://github.com/utmhikari/GAutomatorUnrealSDK)项目中，修复intellisense的问题以及添加了一个获取指定Actor的功能样例。并且由于GAutomatorAndroid中的Python库和Unreal插件所提供的功能是高度耦合的，因此GAutomatorAndroid的相应基础库也需要更新。

由于GAutomator原先对于Unity的支持较好，但笔者暂时没踩Unity的坑，因此仅针对Unreal而言，从第一次上手的体验来看，GAutomator还有许多优化点，比如：

- GAutomator的设定更类似客户端中的一个内嵌的GM指令服务端，但当前的“客户端”是纯粹的Python库，因此需要因GAutomator插件实现的功能而进行维护更新。理想的方式是采用GUI+蓝图的用户体验实现，通过提交任务的方式交付给GAutomator Unreal插件，在插件内部执行对应的自动化任务。
- 针对游戏用例的多样性，需要更多对世界实例进行操作的底层功能支持。业务用例的维护不能对这些底层功能造成影响，已经写好的底层功能仅因引擎实现以及实体操作需求的改变而改变。
- 大批量、多次游戏用例需要考虑前置条件生成/状态保存等需求，这些需求可能需要在自动化指令的基础上去结合预配置的GM指令。因此如何解耦这些不同的业务模块，也是需要考量的问题。

总的来看这块还有很多有待挖掘的地方。如果有机会实战的话，再看看吧~
