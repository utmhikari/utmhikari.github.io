---
title: 【Easy Python】第一话：print('HelloWorld')——输入、输出与函数
date: 2019/03/09 18:06:45
categories:
- Easy Python
tags:
- python
- 教程
- 函数
- 输入
- 输出
---

## 前言

这个年代，连小学生都会Python了，我家领导还是一行代码都打不出。
网上的Python教程一抓一大把，但出于让人更加深刻理解以及实用的目的（尤其是我家领导），Easy Python，开始挖坑！

## 安装Python

这个没有教程= =，请安装3.*最新版Python
编辑器建议为vscode 、sublime之类（记得装插件），如若觉得装插件烦可直接上pycharm
Easy Python系列不展现实时交互式命令~

## HelloWorld

学程序的第一行代码，大概都是Hello World吧！

```python
print('Hello World!')
```

然后命令行里，就会输出：

```text
Hello World!
```

那如果要打出1行100个Hello World的话，该怎么办呢？
如果这样的话：

```python
for i in range(100):
    print('Hello World')
```

试试看，会打出100行HelloWorld，不符合我们的需求
这个时候，该怎么办？

<!-- more -->

### 输入与输出

程序本质就是：输入 -> 函数（function）->输出。输入的raw data，经由一个叫函数的东西处理，就能输出我们想要的数据。
如果一个函数，没有输入输出，也没关系。这样，函数就单纯是一个数据处理过程而已了。

在先前的HelloWorld，就似乎是这么一个结构：

- 输入：Hello World
- 函数：print
- 输出：命令行中打出Hello World

所以，咱们可以从函数入手：可不可以定制一下print，让咱们的Hello World能够打出来不换行呢？
看一看print这个函数（function）的源码:

```python
def print(self, *args, sep=' ', end='\n', file=None):
    ...
```

可以看到，print函数有个end='\n'的参数。顾名思义，每次print一下，输出的字符串结尾都有一个'\n'。'\n'是换行符，那么就说明，单纯的print100下，就会出100行HelloWorld嘞
因此，要解决咱们的需求也很简单，指定end为不换行，覆盖掉默认参数就好了~

```python
for i in range(100):
    print('Hello World', end='; ')
```

试试看吧~

### 函数

函数，function，就像活字印刷的活字跟流水线上的机械处理器一样，是可以复用的处理过程，是通用的功能。
函数的输入叫做**参数**（arguments, args）；函数的输出可称作**返回**（return）。
print就是一个最典型的函数，我们写代码时常常print数据出来调试。print函数，就是这么实用。
现在让我们再次回顾一下print的函数怎么定义的（def），这回，咱们把注释也给打出来~

```python
def print(self, *args, sep=' ', end='\n', file=None):
    """
    print(value, ..., sep=' ', end='\n', file=sys.stdout, flush=False)
    Prints the values to a stream, or to sys.stdout by default.
    Optional keyword arguments:
    file:  a file-like object (stream); defaults to the current sys.stdout.
    sep:   string inserted between values, default a space.
    end:   string appended after the last value, default a newline.
    flush: whether to forcibly flush the stream.
    """
    pass
```

### 参数

我们可以看到，print函数中，规定了这么些参数：*args, sep, end, file

首先咱们来看第一个参数——\*args。顾名思义，就是一堆参数（arguments）的称呼。参数开头为单星号\*，就代表这是一堆**无关键字参数**，就叫“无名参数”好啦
而像sep=xxx, end=xxx之类的，都是**参数名=参数值**的结构，它们就叫——**关键字参数**（keyword arguments, kwargs），如果要表示一堆关键字参数，我们可以用：\*\*kwargs

说了这么些，不如咱们来试试输入：我爱你

```python
print('Wo', 'Ai', 'Ni')
```

输入了三个无名参数，结果是：

```text
Wo Ai Ni
```

可以看到，三个无名参数都被打出来了，都被空格分隔。这个时候，我们就知道sep参数（separator）的作用了。所以，让我爱你不分隔的方法是~

```python
print('Wo', 'Ai', 'Ni', sep='')
```

```text
WoAiNi
```

最后一个file参数，指定了我们在哪里print出结果。默认值是sys.stdout，标准输出流，咱们在cmd小黑框里常看见的那些白字就是里边出来的啦。
不如，咱们试试把WoAiNi打进文件里？

```python
# 默认file=sys.stdout，系统标准输出流
# 因此要自定义file，则应当要赋予同类型的参数
# file应该指定成一个输出流，类似一个数据写入通道
# python内置了open('文件名', 'w')的方法，可以创造一个文件的写入流
# 其中'w'代表write，即写入模式
# 可不能单纯file='woaini.txt'喔，怎么能赋一个字符串上去惹
print('Wo', 'Ai', 'Ni', sep='', file=open('woaini.txt', 'w'))
```

打开python文件同目录下，是不是多了一个woaini.txt啦~快去瞧瞧吧！

### 返回

说到这么多，print的返回值，真的是上面所说的"命令行中打出Hello World"嘛
当然不是拉= =
我们其实可以用print打一下print的返回值，了解一下：

```python
a = print('woaini')
print(a)
```

结果是：

```text
woaini
None
```

在python里，None是一个抽象的符号，是python内置的关键字（不是函数的关键字！），代表无，没有数据。
也就是说，print，返回了None。
so，命令行的输出算什么呢？
我们再拿个例子：

```python
def func(x, y):
    print('woaini')
    return x + y


a, b = 1, 1
print(func(a, b))
```

打出来

```text
woaini
2
```

可以看到，最下边的print，要打出函数func(a, b)的结果，因此先执行func。在执行func的期间，打出了woaini。然后才返回了x + y的结果。之后，才打出来1+1的结果，等于2。
可以看到，我们要根据return才知道函数返回什么，其它部分的输出都只是函数过程的副产物。没有return，就默认返回None。
因此整个print的过程，我们可以总结为：

- 参数：自定义参数（*args, sep之类）、print的默认参数
- 函数：print
- 过程：打出Hello World到标准输出流中，使得我们在命令行看到
- 返回：None

## 总结

函数无处不在，不仅是print，就连你执行的python脚本，本身也可以当做一个函数。
我们建一个文件：1.py，里面内容为：

```python
# 导入内置的“系统功能”模块：sys
import sys
# print出执行1.py的参数
print(sys.argv)
```

然后，cmd命令行里进到1.py目录下，输入python 1.py 123 abc qwer gogo aini看看结果吧~

---

至于第一话的意识流——输入、输出与函数，其实是个超级大坑，不是三言两语能够说清楚的。但是，我希望能够创造这样一个效果，让我们阅读代码跟阅读普通英文文章一样顺畅，让我亲爱的领导在参阅我的文章之后，能对码代码有新的认知与想法！

通篇文章，暂且一气呵成，有叙述不妥之处，欢迎指正！
