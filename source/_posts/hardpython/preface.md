---
title: 【Hard Python】前言
date: 2022/01/08 14:04:51
categories:
- Hard Python
tags:
- python
- 教程
- Medium Python
- Easy Python
- 源码分析
---

写完Medium Python之后，不知不觉就有开始继续写Hard Python的冲动。择日不如撞日，心动不如行动，2022年开篇，果断将Hard Python提上日程。

截至2021年底，python依旧是最热门的语言之一，随着3.10、3.11及后续版本的发布，python的runtime在功能及性能上都会有较大的提升。时至今日，提到技术应用最广泛的语言，除了python，还会有另外的吗？排除区块链、游戏、音视频里较为深度的领域，基本上各种技术业务场景，都会有python的影子。

可以说，python是编程界的一把瑞士军刀。如果我们能更加深入的了解python各个重点模块的技术原理，不仅对于我们理解这门语言以及编程语言相关技术有益处，并且以后我们在面对一些python的编程场景时也会更加得心应手。

在先前已经写过两个python系列，分别是[Easy Python](https://utmhikari.top/categories/Easy-Python/)以及[Medium Python](https://utmhikari.top/categories/Medium-Python/)。在Easy Python中，对python的各种基础概念以及实用场景介绍了相关案例；而在Medium Python中，通过源码分析的方式，剖析了python内部某些语言特性的实现，讲述了许多python相关的冷知识。这次Hard Python，还是回归本源，将会挑选一些python内部比较重点的基础模块进行深入剖析讲解，争取让每一位阅读本系列文章的同学对python这门语言有更加全新的理解。

话不多说，准备上菜！

## 目录

- 第一章：多线程
  - [1、Process，新进程的诞生](https://utmhikari.top/2022/01/16/hardpython/1_multiprocessing_1/)
  - [2、Pipe和Queue，进程间通信](https://utmhikari.top/2022/01/22/hardpython/1_multiprocessing_2/)
  - [3、Pool，多任务并行进程池](https://utmhikari.top/2022/01/30/hardpython/1_multiprocessing_3/)
- 第二章：异步IO
  - [1、asyncio事件循环的创建](https://utmhikari.top/2022/02/12/hardpython/2_asyncio_1/)
  - [2、异步任务在事件循环中的执行](https://utmhikari.top/2022/02/20/hardpython/2_asyncio_2/)
  - [3、async/await的源码实现](https://utmhikari.top/2022/02/26/hardpython/2_asyncio_3/)
- 第三章：GC
  - [1、引用计数与内存释放机制](https://utmhikari.top/2022/03/12/hardpython/3_gc_1/)
  - [2、python的GC流程](https://utmhikari.top/2022/03/19/hardpython/3_gc_2/)
- 第四章：日志
  - [1、Logger与Manager的源码实现](https://utmhikari.top/2022/04/09/hardpython/4_log_1/)
