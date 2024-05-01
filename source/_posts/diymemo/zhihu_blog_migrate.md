---
title: 【DIY小记】用爬虫+clean-mark+zhihu-on-vscode搬运技术博客到知乎
date: 2024/05/01 18:36:27
categories:
- DIY小记
tags:
- python
- 爬虫
- BeautifulSoup
- clean-mark
- zhihu-on-vscode
---

今天灵光一闪，决定调研一下自己的技术博客，可以怎样方便迁移到其它社媒平台。想要达到的效果是，把自己在掘金的专栏：[从1到∞精通Python](https://juejin.cn/column/7240333779223330872)，迁移到知乎上面去。

简单花了两三小时时间，找到一个比较快捷的方法，就是结合python爬虫、clean-mark工具和zhihu-on-vscode插件，实现从掘金到知乎的文章搬运。

<!-- more -->

首先是爬虫，给定一个掘金专栏的url，直接get就能拿到整个网页信息，包括这个专栏的标题、描述还有所有文章的标题跟URL。用BeautifulSoup写个50行左右解析一下，就能够把所有信息给拿出来。

然后是用[clean-mark](https://github.com/croqaz/clean-mark)，遍历所有的文章url，就能够把所有文章的markdown给拿出来。

最后是用zhihu-on-vscode插件，把markdown文件直接上传到知乎。知乎平台本身不支持复制markdown文本，但支持导入markdown文件。这个插件把知乎的平台交互收敛到了vscode里，并且能直接上传markdown到专栏，非常方便。

通过这三个工具的结合，笔者花了一个上午，就实现了所有Python专栏文章的搬运。新专栏的链接在[这里](https://www.zhihu.com/column/c_1769036952685379585)，如果你想彻底拿捏Python，那这个就是你的菜。
