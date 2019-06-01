---
title: 【Easy Python】最终话：Python, 就是这么Easy！
date: 2019/05/19 17:01:35
categories:
- Easy Python
tags:
- python
- 教程
- 知识总结
- 笔记
- easy python
---

## 前言

Easy Python终于来到完结，我的领导也夸奖我写作非常的卖力用心。对此，我深表欣慰！

六章Python讲解，并不单纯是切磋代码技艺，而更是注重于每一行代码背后发生的事儿

为此，让我们一起重回首Easy Python系列，光荣收尾吧！

<!-- more -->

## 回顾

### [第一话：print('HelloWorld')——输入、输出与函数](https://utmhikari.github.io/2019/03/09/easypython_i/)

HelloWorld，是代码世界的入口。当我们采用Python语言打下print('HelloWorld')的一刻，是否想过print——这个函数，到底表示什么呢？到底能怎么用呢？

这个话题就可以衍生到“函数”（功能模块）相关的话题。把一个大的程序进行过程解耦，我们可以分解之为小的功能模块。每一个模块都有相应的输入与输出，这样就把整一个程序串起来了。

在第一话，我们提到的知识有：

- 函数与过程（function & process）
- 输入&参数&关键字/无关键字参数（input, arguments, *args & **kwargs）
- 输出&返回（output & return）

### [第二话：映射——输入、输出与函数的纽带](https://utmhikari.github.io/2019/03/16/easypython_ii/)

映射代表了输入与输出的关系，而函数则实现了映射。在我们日常码码中，如果能用映射的方式表示一段程序，能够增强代码的可读性

在第二话，我们提到的知识有：

- 映射（mapping）
- 字典及其映射实现（dict & hash）
- 函数式编程&python示例（functional programming with its example）

### [第三话：爬虫初探——玩转豆瓣二百五（上）](https://utmhikari.github.io/2019/03/31/easypython_iii/)

python在数据分析方面的应用非常广泛。在网上有非常多的爬虫教程，然而爬虫背后到底干了什么，我们却不易知晓。

同样，豆瓣top250电影的信息爬取也是许多同学的入门之径。Easy Python也是一样，采用上下两话介绍豆瓣250的python爬虫——爬什么，怎么爬，为什么这么爬——所有的一切，全部浓缩成精华。

在第三话，我们抓取了top250电影的链接，所涉及到的知识有：

- 网络基础：HTTP、URL、协议、状态码等（HTTP, URL, Protocol, Status Code, Resources, etc）
- HTML网页与BeautifulSoup解析（HTML page & BeautifulSoup Parser）
- Chrome开发者模式（Chrome Developer Mode）

### [第四话：爬虫初探——玩转豆瓣二百五（下）](https://utmhikari.github.io/2019/03/31/easypython_iv/)

豆瓣二百五的下篇相对于上篇，爬取了每一个电影链接中的具体电影信息。从编程角度而言，涉及的知识面就更广了：

- 异步并发调度与asyncio库（asynchronous programming & asyncio usage）
- 阻塞与非阻塞任务（blocking & non-blocking tasks）
- 爬虫代理池&生产者——消费者调度（proxy pool & producer-consumer model）
- 条件变量及其等待&唤醒机制（condition variable & wait-notify mechanism）

注重代码工程化（强迫症）的同学们，千万不要错过~

### [第五话：小试scikit-learn数据挖掘——newsgroup数据处理与文本分类](https://utmhikari.github.io/2019/04/14/easypython_v/)

第五话对数据处理&文本分析的基本操作做了讲解，简要地介绍了文本分类的概念与操作，并且打通了Python的机器学习库与我们自己的数据。

在这一话中，涉及到的知识有：

- 数据挖掘，机器学习&文本分类（data-mining, machine-learning & text-classification）
- 正则表达式（regular expression）
- scikit-learn文本分类流水线（pipeline of text-classification via scikit-learn）

### [第六话：解锁三头六臂——Python多进程并行](https://utmhikari.github.io/2019/05/11/easypython_vi/)

第六话，讲述了许多同学所关心，踩坑较多的并发编程，剖析了其中原理，并用python实现多任务并行操作。在这方面有疑惑的同学们，千万不要错过！

在这一话中，涉及到的知识有：

- 并发&并行任务（concurrent & parallel tasks）
- 线程、进程的特性与关系（features & relations of thread & process）
- 多线程&多进程（multi-threading & multi-processing）
- python进程资源共享（shared data on pythonic-multi-processing）
- 客户端/服务器模式与tornado框架（C/S model & tornado framework）

## 总结

从编程爱好者们的角度评价python的话，就好比CSGO玩家评价P90这把武器——“noob gun”，是个人都能上手用起来，太TM简单了。

但是，python的easy仅限于上手容易吗？相对于python，lua对新人那是更加友好，就连我家那笨笨的领导，都说lua看的比python容易。

python简单的意义在于背后强大的社区一直不断地推动着python的轮子，使得我们在各个场景都有轻松驰骋的可能。大多数情况下，我们并不追求完美的质量，但求快速实现基本的操作，那就选择python吧！

Easy Python, lemon squeezy~
