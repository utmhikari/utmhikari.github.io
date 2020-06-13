---
title: 【测试人生】代码覆盖率测试之代码染色优化——以lua代码覆盖为例
date: 2020/06/13 14:47:09
categories:
- 测试人生
tags:
- 代码覆盖率
- 代码染色
- 语法分析
- 递归下降法
- lua
---

在研发代码覆盖率测试工具的时候，通常除了代码覆盖数据收集模块之外，一般还要研发前端展示的部分以展现代码覆盖分析报告，通常会为每一个文件增加行染色，类似于[jacoco](https://www.jacoco.org/jacoco/trunk/coverage/org.jacoco.core/org.jacoco.core.internal.analysis.filter/TryWithResourcesJavacFilter.java.html#L184)这种形式。

然而代码覆盖报告实际出来的行染色，会出现许多正常代码行没有着色的情况。这是因为编程语言认为的“行”和本身我们在文本编辑器打出的”行“是不一样的。编译出来的“行”实际上是一段操作，比如我们定义一个函数的时候，编译器认为我们执行的操作有包括function xxx那一行，于是就有一种情况——我们实际没有运行过这个函数，但由于定义被覆盖，因此出现function xxx染绿，而函数体染红的现象。从用户的角度而言，用户如果对代码编译这块并不熟悉的话，就会造成理解上的偏差。

因此考虑工作成本，如果有必要的话，需要对代码覆盖数据进行修改，从而展现更好的代码行染色效果。以lua为例，可以采用这样的方法：

<!-- more -->

lua代码收集已经在[luacov源码分析](http://utmhikari.top/2019/03/10/luatalk/luacov/)有相关解读，这块不赘述。在代码编译的语法分析方面有一个经典的方法叫做[递归下降法](https://zhuanlan.zhihu.com/p/31271879)，如果需要测定覆盖率的语言是像lua这样简单的话，就可以直接应用。我们可以从lua文件原始的覆盖数据，推断近乎真实的覆盖数据。首先把一个文件所有的代码分为不同的chunk：

- main chunk
- loop end chunk
- do end chunk
- (local) function end chunk
- if elseif else end chunk

而后自顶向下递归下降遍历代码行。我们起始就已经在main chunk，因此理论上来说，main chunk中所有不是其它子chunk的代码都能被覆盖到（当然也包括do end）。而后针对loop、if/elseif/else、function，则采用如下的判断机制：

- loop内及loop语句本身的代码行覆盖多少次算多少次
- function内如果一行都没有覆盖，那么function与end声明也算没有覆盖。就算是return function() end也一样，因为用户比较关心这个function实际是否有运行
- if方面，统计每个if、elseif、else块的代码覆盖，分为三种状态：全部覆盖、部分未覆盖、全部未覆盖。

lua本身是不支持检测if事件的，但实际通过语法分析，可以检测到if代码块，这样我们就可以像jacoco一样，为if代码行染一个不同的颜色。至于代码染色如何标记，其实可以用int32的高几位来标记对应行的颜色就好了，这种方法在做增量覆盖的情况下也适用。

如果出现xxx end在同一行的情况，那就更好办了，该覆盖几次是几次。

假定程序员写代码写的比较规范的话，用这种方法进行行染色展现代码覆盖报告，效果可是真的杠杠的。
