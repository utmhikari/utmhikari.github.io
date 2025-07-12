---
title: 【DIY小记】CSGO究极装机优化设置指南
date: 2019/09/21 10:55:00
categories:
- DIY小记
tags:
- CSGO
- Win10
- NVIDIA
- 游戏
- 渲染
---

## 前言

上周电脑突发极其奇怪的bug，启动了不到一会儿CPU阻塞，所有程序打不开，安全模式查毒、修复系统、清存储卸软件均没有获得较好的效果。因此索性重装了Windows，所有一切推倒重来。

既然推倒重来，那CSGO就是不得不装的一款游戏。CSGO到现在也有10年的历史了，然而在网上能搜到的游戏优化设置要么过时，要么没有详尽的整合。因此，本文章借着装机经验，整理了自己优化CSGO的历程~

由于笔者为Win10+N卡，因此在Linux/Mac以及非N卡下玩CSGO的同学，部分配置还需另行google~

## Win10游戏设置

运行在Win10的游戏需要关闭Win10自带的游戏优化与配置

首先关闭XBox自带的DVR（游戏内录像之类），有很多种方法，这里通过注册表方式解决：

<!-- more -->

```text
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\System\GameConfigStore]
"GameDVR_Enabled"=dword:0
[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR]
"AllowGameDVR"=dword:0
[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR]
"value"=dword:0
```

新建`disableDVR.reg`将以上文本复制进去，执行即可。

如果对注册表不熟悉的话，可以另外百度搜直接在系统设置关闭的方法（非常多，随便挑一个就好），比如[这个](https://www.pconline.com.cn/win10/1077/10772807.html)。

然后就是查缺补漏了。打开`系统设置——游戏`，在`游戏栏`条目关闭`使用游戏栏录制剪辑、屏幕截图和广播`，如图：

![游戏栏](/uploads/diymemo/csgo/gamebar.png)

而后，在`游戏模式`条目，关闭`游戏模式`，否则CSGO画面虚的一笔。

![游戏模式](/uploads/diymemo/csgo/gamemode.png)

如果出现有条目不同的情况，可能是系统版本不同的原因（笔者为1903）~

## 鼠标设置

鼠标设置必须要做的一个是关闭鼠标加速：

打开`控制面板`，选择`鼠标`中的`指针选项`一栏，取消勾选`提高指针精确度`

![指针精确度](/uploads/diymemo/csgo/cp_mouse.png)

而后，如果你的鼠标有额外驱动程序（比如雷蛇），需要下载驱动程序去鼠标加速然后diy一个自己感到舒适的配置。如果没有，那就可以继续下面了。

## N卡设置

首先安装N卡图形驱动（可以官网搜也可以用驱动软件），如果成功的话，我们就能够找到`NVIDIA控制面板`了。

在`NVIDIA控制面板`下设置N卡，具体如下：

首先进入`通过预览调整图像设置`条目，拖动条为侧重性能：

![预览](/uploads/diymemo/csgo/nvidia_preview.png)

而后进入`管理3D设置`条目，全局设置着重性能而非质量。当然如果你想某些其他游戏着重质量，可以不改全局设置，而修改程序设置。

之后进入`配置Surround、PhysX`条目，将PhysX设置为显卡而非CPU：

![PhysX](/uploads/diymemo/csgo/physx.png)

适用于CSGO的设置如下：

![N卡1](/uploads/diymemo/csgo/nvidia1.png)

![N卡2](/uploads/diymemo/csgo/nvidia2.png)

如果部分设置条目不同，应当为NVIDIA显卡型号或驱动版本不同所致，需要另行检索~

再然后就看个人情况了。比如你csgo分辨率为4:3但又想全屏没黑条的话，可以在`调整桌面尺寸和位置`条目中的`缩放`选择`全屏`，并勾选`覆盖由游戏和程序设置的缩放模式`，记得把刷新率也设置到最高~

![全屏](/uploads/diymemo/csgo/fullscreen.png)

## 启动参数

自己电脑CSGO在steam内启动参数如下：

```text
-novid -high -tickrate 128 -preload -refresh 120 -useforcedmparms -noforcemspd -noforcemaccel +exec autoexec.cfg
```

笔者为神船刷新率120Hz显示器，因此启动参数会填写了`-refresh 120`，其他小伙伴请根据自己显示器最大刷新率填写`-refresh`参数，比如144、200多啥的。

最后会启动时执行`autoexec.cfg`，其内容如下：

```text
rate "128000"
cl_cmdrate "128"
cl_updaterate "128"
cl_interp "0"
cl_interp_ratio "1"
cl_lagcompensation "1"
r_dynamic "0"
r_drawtracers_firstperson "0"
fps_max "300"
cl_radar_always_centered "0"
cl_radar_scale "0.3"
cl_hud_radar_scale "1.15"
cl_radar_icon_scale_min "1"
cl_radar_rotate "1"
snd_mixahead "0.05"
```

是一个稳当但并非最牛皮游戏体验的设置。如果要追求最佳游戏体验，比如可以设置`fps_max "999"`之类。

`autoexec.cfg`需要存储到`${Steam游戏目录}\steamapps\common\Counter-Strike Global Offensive\csgo\cfg`中才可以执行到。其它的cfg脚本也同样如此。

## 游戏内部设置

接下来是游戏内部的设置，首先是`视频设置`，效果全低，着重性能即可。

为了方便截图，采用了窗口模式：

![视频](/uploads/diymemo/csgo/video.png)

用本本的小伙伴需要同时设置`显示设置`为`电视`，这样会有更好的颜色效果。

而后是鼠标，打开`键盘/鼠标`一栏，启用原始数据输入，关闭鼠标加速

![鼠标](/uploads/diymemo/csgo/mouse.png)

其它设置因人而异。

## 总结

音频方面的优化还没有系统的概念，而且因耳机效果而已，因此需要另行搜索啦~

其它地方，如果有缺，求留言补充~

如果配置不当，恳请指正~
