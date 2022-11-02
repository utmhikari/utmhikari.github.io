---
title: 【DIY小记】Ubuntu22.04去掉侧边菜单栏Floppy Disk图标的方法
date: 2022/10/15 12:17:54
categories:
- DIY小记
tags:
- Ubuntu
- Floppy Disk
- linux
- 操作系统
- 系统设置
---

近期装`Ubuntu22.04`虚拟机，发现侧边菜单栏多了个`Floppy Disk`图标。软驱这东西毕竟是上世纪的了，2022年也没什么用，但就是找不到入口去掉这个冗余的图标。

今天偶然之间发现去掉图标的方式，供大家参考：

- 右上角点`电源/声音/网络按钮`，选择`Settings设置`
- 选择`Appearance`，就是能调`Light/Dark`风格的页签
- 下拉，在`Dock`栏目下，点击`Configure dock behavior`
- 里面的`Show Volumes and Devices`下，有一个`Include Unmounted Volumes`项。反正软驱一般也不会挂载，所以取消点选这个项，`Floppy Disk`图标就没了。
