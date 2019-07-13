---
title: 【测试人生】安卓FPS测试详解
date: 2019/07/13 16:51:27
categories:
- 测试人生
tags:
- 测试
- fps
- Android
- 性能测试
- SurfaceFlinger
---

安卓的fps测试，是我打开测试开发大门的一把钥匙。两年前的现在，安卓性能测试的相关资料甚少，以fps为例在网上也只有寥寥几篇文章讲述，但到了今年，已经有许多资料在各大技术论坛上供大家看到了。对于自己，一直想找一个机会把这一段技术探索写出来。所以，心动不如行动。

fps（frames per second），通常表示我们屏幕每秒展现的图片（帧）数，反映了一款应用在当前硬件下的性能消耗。比如我们抽CS的时候，就经常关注fps是否高，在高的情况下，就会有较好的流畅度。因此fps是应用性能测试中一个重要指标。

对于一个安卓app而言，为了测定fps数值，我们需要从安卓图形显示相关的模块入手。一个通用的方式是切入安卓的SurfaceFlinger服务，它是图形显示流程中软件层和硬件层的交互点，是极其关键的一环。SurfaceFlinger则是负责分析&合成各个app中的图层，而后将合成的图像数据交由硬件渲染。硬件渲染的机制复杂，因此安卓系统中，将硬件操作进行了抽象方便调用，我们将这一与SurfaceFlinger对接的层次，称之为硬件抽象层（HAL）。SurfaceFlinger与HAL在功能上有部分的耦合，一些Surface合成的工作，也会委托HAL进行。

那么我们该如何通过SurfaceFlinger获得fps数据呢？大体上，我们可以参考[《Android性能测试之fps获取》](https://blog.csdn.net/itfootball/article/details/43084527/)一文。这种方式成功率高（虽然我家手机行不通），且不用root，较为方便

首先，通过adb，我们可以导出SurfaceFlinger服务的运行时信息。

```sh
adb shell dumpsys SurfaceFlinger
```

dump出的信息包含了每个图层经过SurfaceFlinger加工后的信息，以及在硬件显示层上的层次，例子如下：

```plain
+ Layer 0x796c18e800 (com.supercell.clashroyale.kunlun/com.supercell.clashroyale.GameAppKunlun#0)
  Region transparentRegion (this=0x796c18eb90, count=1)
    [  0,   0, 1080, 2240]
  Region visibleRegion (this=0x796c18e810, count=1)
    [  0,   0,   0,   0]
  Region surfaceDamageRegion (this=0x796c18e888, count=1)
    [  0,   0,   0,   0]
      layerStack=   0, z=    21015, pos=(0,0), size=(1080,2240), crop=(   0,   0,1080,2240), finalCrop=(   0,   0,  -1,  -1), isOpaque=0, invalidate=0, dataspace=(deprecated) sRGB Linear Full range, pixelformat=RGBA_8888 alpha=1.000, flags=0x00000000, tr=[1.00, 0.00][0.00, 1.00]
      client=0x796fb03ec0
```

一般来讲，我们会选择前台的app进行fps统计，因此要选择visible region足够大，且z轴为正的层。除了这个筛选点之外，也可在HAL中的硬件合成（HWC）的信息中，筛选我们想要获取数据的图层。

得到图层后，我们可以输入以下命令，导出该图层渲染的时间数据：

```sh
adb shell dumpsys SurfaceFlinger --latency <图层名>
```

如果成功的话，会显示出三列数据，大概是这样：

```plain
// 抠图 from chromium android pylib
16954612
...
7657467895508   7657482691352   7657493499756
7657484466553   7657499645964   7657511077881
7657500793457   7657516600576   7657527404780
...
```

所有数据以纳秒为单位。第一行表示显示器刷新频率（16.95ms），一般为固定值。剩下每一行代表一个帧的时刻数据，三个时刻数据分别表示：

- app绘图时刻（A）
- 垂直同步信号来临时刻（B）
- SurfaceFlinger把帧全部提交给硬件的时刻（C）

所谓[垂直同步（VSync）](https://baike.baidu.com/item/%E5%9E%82%E7%9B%B4%E5%90%8C%E6%AD%A5)，玩竞技游戏的同学应该都非常了解，它是与显示器刷新率挂钩的。通常情况下，显示器有多个缓存，显卡在其中一个缓存绘图，而显示器在另外的缓存读取帧数据显示在屏幕上，然而由于显卡绘图的速度总是会比显示器刷新的速度快，如果显卡实在没地方，最后跑到显示器读取帧的缓存写入数据的话，那显示器可能上半部是一个帧的，下半部分成另一个帧的样子了，造成画面撕裂。因此，显示器通过这个机制阻塞显卡绘图至其它的缓存，从而保证显示画面的流畅运行。

一般安卓的app开启了垂直同步，因此通过`数据行数 - 1/ΔB`，我们就能轻易地获得fps原始值，其中`ΔB`指代最后一个垂直同步时刻减去第一个垂直同步时刻的时间差。

但除此之外，我们还要考虑绘图掉帧（jank）的因素。所谓掉帧正好与前面的画面撕裂相反，是由于系统调度问题，导致下一个VSync信号来了时，下一个图片数据没准备好，这样显示器就又把上一帧数据给显示了一次。通过统计`C - A`，我们就可以看到每一次绘图~硬件显示的时间差，理论上有垂直同步的情况下，这个时间差是定值。而实际情况下，只要这个时间差有变动，就说明有掉帧的情况了。

这样一来，我们通过fps原始值，减去时间差变动的次数（掉帧次数），就能获得真实的fps值了。
