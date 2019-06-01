---
title: 【DIY小记】Windows编程字体&主题设置
date: 2019/06/01 15:00:50
categories:
- DIY小记
tags:
- 字体
- 编程
- Windows
- 主题
- 皮肤
---

## 前言

编程需要纠结字体跟皮肤吗？肯定要纠结的啦= = = =

调理字体跟皮肤，就跟打扮房间一样。每当我们打开编程软件之时，要是看到的都是清亮的字体，爽快的皮肤，心里肯定就特别踏实，码码起来肯定也就特别舒服。

是时候分享一下我的编程字体以及主题设置了！！！

<!-- more -->

## 电脑配置

### 显示

显示方面，主机用的最高分辨率1080p的船，接了HDMI到华硕MG248QR显示器，刷新率120hz。

### 编程软件

编程软件主要是4个：

- Visual Studio Code：主力开发&写博客
- IntelliJ Idea：写python、java用
- Visual Studio：Unity跟Unreal用
- Notapad++：日常文本编辑

## 字体&主题配置

由于Windows天生渲染不咋地，比Mac差了一大截。因此选择字体搭配皮肤，那可得得下一番功夫。

### Visual Studio Code

自己的配置是：Cobalt2主题 + Operator Mono Light字体（大小14），行高22

拿lfunctimer的lua文件做例子，加了lua coder assist、TODO highlight等插件，效果如下：

![VSCode Cobalt2 + Operator Mono](/uploads/diymemo/font_theme/vscode_cobalt2_operator_mono.PNG)

主题的选择很多样，官方的Dark+其实已经很不错了。但是推荐的话，One Dark Pro Vivid跟自带的Monokai都是不错的选择。**Material系列主题千万不能选！！！看久了非常伤眼，低对比度不好看，高对比度太伤眼。**

图标主题（Icon Theme），可以选Material系列，也可以选VSCode Great Icons之类，比较随意。

字体的话，实测Fantasque Sans Mono与Ubuntu Mono是推荐的选择。Consolas跟Source Code Variable会稍微有点肥的感觉，而Inconsolata跟Monaco系则会有一些渲染上的瑕疵。

我们可以看看Monokai + Fantasque Sans Mono以及One Dark Pro Vivid + Ubuntu Mono的效果：

![VSCode Monokai + Fantasque Sans Mono](/uploads/diymemo/font_theme/vscode_monokai_fantasque_sans_mono.PNG)

![VSCode One Dark Pro Vivid + Ubuntu Mono](/uploads/diymemo/font_theme/vscode_one_dark_pro_ubuntu_mono.PNG)

### IntelliJ Idea

Idea方面，主题首选官方出的新皮肤：Dark purple。**千万不要安装Material皮肤，缺点上面已经说了，而且卸载难，简直是流氓插件。**

字体方面，Idea有读取不到Operator Mono的bug。Windows上，首先在Appearance设置里把Editor的抗锯齿设置为Greyscale：

![Idea Greyscale](/uploads/diymemo/font_theme/idea_greyscale.PNG)

然后首选Fantasque Sans Mono，中文字体苹方（fallback font设置），极度舒适，效果如下：

![Idea Fantasque Sans Mono](/uploads/diymemo/font_theme/idea_fantasque_sans_mono.PNG)

Monaco系也不错，HeyMona或Monaco for Powerline都有不俗的显示效果：

![Idea HeyMona](/uploads/diymemo/font_theme/idea_heymona.PNG)

如果是小屏幕，也可以用Source Code Variable，但大屏幕会显胖。有兴趣的同学可以试试~

### Visual Studio

Visual Studio的字体渲染是真的辣鸡，能看的字体真的太少了。

可以选择Dark主题 + Inconsolata或Ubuntu Mono字体的配置，字体要设小一点，两个的展现效果都差不多。直接以Inconsolata为例好了= =

![VS Inconsolata](/uploads/diymemo/font_theme/vs_inconsolata.PNG)

### Notepad++

Notepad++跟Visual Studio渲染的效果相似。因此，字体上同样采用Inconsolata或者Ubuntu Mono即可。

主题的选择上，Monokai或者Obsidian都不错。Obsidian的关键字标粗体，由于Inconsolata跟Ubuntu Mono在Notepad++上粗体显示并不算特别完美，所以如果懒得去DIY的话，选Monokai就好了。

我们可以一睹Monokai + Inconsolata以及Obsidian + Ubuntu Mono的效果：

![Notepad Inconsolata](/uploads/diymemo/font_theme/notepad_inconsolata.PNG)

![Notepad Ubuntu Mono](/uploads/diymemo/font_theme/notepad_ubuntu_mono.PNG)

## 总结

如果想要复古，或者没太多审美需求，Consolas、Courier (New)之类的就可以满足了= =s

像DejaVu Sans Mono、Droid Sans Mono、Fira Code、Hack、Input Mono之流，网上介绍看着还OK，实际效果还是硬伤。

萝卜青菜，各有所爱。以上设置仅供参考！！！实践，是检验真理的唯一标准~
