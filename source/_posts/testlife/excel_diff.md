---
title: 【测试人生】为游戏策划与QA量身定制的excel表diff算法
date: 2020/01/23 15:20:30
categories:
- 测试人生
tags:
- 游戏策划
- 游戏测试
- excel
- diff算法
- 策划表
---

国内的游戏研发团队里许多策划同学都习惯采用excel作为配表工具。因此对策划同学校对与QA同学验收工作来说，需要相应的diff工具去检测excel文件的变更，从而能够尽早发现配表的问题。为此，在笔者启动的游戏效率工具集[gameff-toolset](https://github.com/utmhikari/gameff-toolset)小项目中，首个小脚本便做了excel diff。

diff的算法有非常多，但是如何体现策划表与策划工作的特性，这才是最需要注意的。许多项目的策划表都通过SVN进行存储，因此从SVN的commit信息中就可以知道哪些策划表发生了变更/增加，因此，我们只需关心每个excel文件如何进行diff运算就可以了。

策划的excel配表有如下的特点：

<!-- more -->

- 每个sheet有表头header，一般为行表头header
- header一般定下后不会再变化
- 不同的sheet，表结构基本不同
- row不一定有主键，甚至同sheet有重复的id
- 每次变更时，变更的行数相对不变的行数较少
- 可能存在将某些行移动到其它位置的情况
- 策划同学在excel某些空白区域可能会加上注释

因此，我们从sheet的粒度来看，diff模块可以这样设计：

- 定义表头行index，数据起始行index，数据起始列index
- 统计增加与去除的表头。如果单纯表头名称改了，下面的数据改动基本没有，也算整个列都改了。这样，列的长度就变得一样了。
- 对于共有的表头，统计下面的行数据，去除不合法的行。如果行中起始列上没有数据，就算不合法。
- 通过求行的hash，来获得变更前excel与变更后excel中行的映射，从而知道哪些行没有变动，哪些行变动了。
- 针对没有变动的行，求变更后excel中这些行的索引的[LIS](https://en.wikipedia.org/wiki/Longest_increasing_subsequence)。具体的求法可以参考[stackoverflow](https://stackoverflow.com/questions/3992697/longest-increasing-subsequence)上的一个帖子，主要思想是用两个数组分别维护长为x的lis的最后一个数的最小索引以及某索引的数作为lis最后一个数时前一个数的索引，然后通过回溯后一个数组，从而获得lis串。通过lis串，我们可以知道哪些行只是单纯地被移动位置，而其中内容并没有被改动过。
- 针对“变动”的行，也分三种情况：增加行，删减行与修改行。由于每次变更所涉及的行一般不多，因此可以采用o(n方)复杂度的方法每行逐格比较。通过逐格比较，可以求出行间相似度，因此我们可以定义一个相似度阈值来判断两行是否相似。如果某个行跟原来的行的相似度大于阈值，就说明这两行相对应，是一个“修改行”的行为，故我们只需记录其中单元格的变化；如果从变更前的某行找不到相似的变更后的某行，就是一个“删减行”的行为；如果有些变更后的行没有变更前的行对应，就是一个“增加行”的行为。

这个模块详细的代码已经写在了[excel_differ.py](https://github.com/utmhikari/gameff-toolset/blob/master/lib/excel_differ.py)中，虽然没有过于细致的整理，可能有许多优化空间，但模块已经拆分的足够明确，并且性能表现也足够OK了。如果拿两个文件夹下的excel文件作为对比的话，可以输出一个类似于[这样](https://github.com/utmhikari/gameff-toolset/blob/master/test/excel_differ/report.json)的json报告。因此若要投产，不论是单纯copypaste脚本，还是接到web server，都绰绰有余了。
