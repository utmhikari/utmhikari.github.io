---
title: 【GitHub探索】安卓自动化测试工具SoloPi
date: 2019/08/11 16:03:54
categories:
- GitHub探索
tags:
- SoloPi
- Android
- 性能测试
- 录制回放
- 自动化测试
---

## 前言

随着MTSC2019的召开，八月份各种测试工具相继开源，其中一款名为[SoloPi](https://github.com/alipay/SoloPi)的安卓自动化测试在月trending榜中排位靠前。移动App自动化测试是当前测试领域的风口之一，并且要开发一款兼容性好、需求适应多样的App，也并非三日之寒。为此，欢迎本期GitHub探索的主角——SoloPi！

![SoloPi主界面](/uploads/githubdiscovery/solopi/main.png)

测试环境为华为P20Pro，安卓版本8.1.0，SoloPi版本为0.9.1，下载地址可进入[GitHub Release](https://github.com/alipay/SoloPi/releases)查看。由于只有一个测试机，所以本次仅测试SoloPi的性能测试以及录制回放功能。下面，让我们开始试水吧~

<!-- more -->

## 准备工作

首先需要准备adb，在[官网SDK Platform Tools](https://developer.android.com/studio/releases/platform-tools)即可下载到。下载后解压，把`platform-tools`目录设置为环境变量`ANDROID_SDK`，然后再加到`PATH`中，这样一方面可以被SoloPi识别，另一方面可以直接cmd adb了。

手机USB接通后，通过`adb devices`可以看到已经连接上的终端。而后按照SoloPi的指示开启权限or开启adb的WIFI调试即可

## 性能测试

不同于传统的通过native导出性能数据到PC端的方式，SoloPi在移动端内部提供图层查看各项性能数据。SoloPi支持的性能指标极其完善，并且提供加压的操作以模拟弱网等场景，非常fit各类测试的需求。

![SoloPi性能测试](/uploads/githubdiscovery/solopi/profile.png)

以皇室战争为例，我们可以在游戏过程中即时地查看性能数据：

![皇室战争性能](/uploads/githubdiscovery/solopi/profile_cr.png)

如果需要有记录性能数据的需求，也可以利用SoloPi提供的录制功能。录制完成后，可以在SoloPi界面里查看录制数据：

![皇室战争性能录制](/uploads/githubdiscovery/solopi/profile_cr_record.png)

由于移动App的限制，在性能数据曲线与实际操作的关联这一块，SoloPi仍然具有局限性。但是我们通过下面的录制回放功能，可以稍微弥补这方面的不足

## 录制回放

SoloPi最引人注目的功能当属录制回放。录制回放功能对Native App支持较好，结合安卓控件监测与图像识别技术识别UI从而记录用户操作。

以九游为例，我们的录制界面如下：

![九游录制](/uploads/githubdiscovery/solopi/record_9game.png)

录制功能不仅支持基本的用户操作（拖拽、点击、长按、输入）及操作的条件界定（exists？assert？match string？），而且支持系统按键、gc、adb等操作。我们可以把它当做移动端WebDriver来使用，并且在录制过程中我们也可以调用性能录制，从而将性能数据与测试过程关联。

录制功能采用用户指定操作+执行的机制，因此会有一定的局限性，比如对于即时性较强的游戏（CR之类）而言，就不能满足测试的需求。但对于一般的App而言，是绰绰有余的。

录制完毕后，我们可以编辑录制的用例：

![用例编辑](/uploads/githubdiscovery/solopi/case_edit.png)

编辑用例的操作，对于不熟悉安卓App的同学来说会有不低的壁垒。如果我们确定用力流程，便可以点击回放。我们可以查看回放的结果以及每个步骤的细节，从而排查用例中存在的问题：

![回放结果](/uploads/githubdiscovery/solopi/case_result.png)

![用例步骤](/uploads/githubdiscovery/solopi/case_step.png)

## 总结

SoloPi所支持的功能满足了大量移动端测试的需求，在自动化方面已经打通了用例录制、性能录制以及用例管理三块。实际入手尝试来看，除了在用例管理以及编辑方面会有略微不便捷的地方之外，其它的测试需求都非常顺利，能够减少了业务测试人员自动化编写的成本，是非常有价值的。

由于前述提到移动App的局限性，因此希望SoloPi后续能积极向外打通链路，让业务实现（尤其是录制结果分析）显得更加灵活。
