---
title: 【测试人生】iOS审核&静态扫描二三事
date: 2019/08/19 23:33:33
categories:
- 测试人生
tags:
- 测试
- iOS
- App Store
- 静态扫描
- iOS审核
---

我们的日常生活离不开手机，有些同学喜欢用国产的安卓机，而另一些同学喜欢用简约的iPhone。

对比安卓和iOS的软件生态，我们可以发现：安卓软件的投放渠道繁多，题材花样繁复，质量大小不一，而iOS的投放渠道则为App Store独家，相对安卓软件来讲，不仅质量均衡，而且用户不必担心手机病毒的困扰。这一点，就归功于App Store严格的审核制度。

<!-- more -->

在iOS App的研发流程中，提审iOS包的环节，一般由运营组完成。在正式提审至App Store前，运营组可能会对研发交付iOS包做人工/静态扫描检查，从而识别并修复提审包存在的违规情况。由于iOS审核规则严厉，周期较长，如果被一次打回的话，后面再等上架成功可就耽误时间了。因此对iOS应用上架而言，预审步骤是非常有必要的。

测试（质量保障）的工作之一便是保证研发交付的效率。由于iOS审核打回对交付流程的阻塞较大，因此实施测试左移，将部分iOS预审流程移至交付运营前实现，这样便能够增加更早发现自家产品违规的概率。苹果的审核流程通常会包括机审与人审两大块，为了减少工作成本，引入模拟机审流程——ipa包静态扫描，是最为常见的做法。

静态扫描的目的是检测提审包资源的完整性与合法性。[App Store审核指南](https://developer.apple.com/cn/app-store/review/guidelines/)为iOS开发者们提供了App审核的参考，而静态扫描这一块，则主要关心第二类（性能）以及第四类（设计）等相关准则，其它的模块要预审的话，需要加持人力得以确认。

ipa包本质是一个zip包。如果有同学好奇拆过的话，可以看到ipa包包含了许多内容：

- Info.plist 元数据
- _CodeSignature 数字签名
- AppIcon 图标
- 二进制可执行文件
- et cetera

对于静态扫描，则至少需要检查以下的点：

- 元数据：元数据的条例繁多，需要参考[About Information Property List Files](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html#//apple_ref/doc/uid/TP40009254-SW1)逐项检查
- 证书：需要结合元数据检查，保证证书有效期，并且为是App Store的发布版本
- 图片：需要保证有特定规格的图片存在，参考[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios/overview/themes/)
- 二进制文件：需要保证[规格](https://help.apple.com/app-store-connect/?lang=zh-cn#/dev611e0a21f)，以及不得包含官方禁止开发者直接使用的api。二进制文件的扫描，相当于对iOS可执行文件的逆向。因此，需要对可执行文件[mach-o](https://www.jianshu.com/p/2eb351b0ce57)的结构以及相关逆向工具（比如[otool](https://blog.csdn.net/lovechris00/article/details/81561627)）的使用进行熟悉

从整个App的审核来看，相对于人工检查，静态扫描的审核点覆盖度相对较低，但却可以对直接对某些审核痛点（比如禁止api）进行检测。因此，聪明的你，也一起来和苹果斗智斗勇吧~
