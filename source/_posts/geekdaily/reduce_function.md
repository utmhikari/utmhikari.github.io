---
title: 【极客日常】理解javascript/python中reduce操作的含义
date: 2021/10/01 12:56:21
categories:
- 极客日常
tags:
- reduce
- 函数式编程
- 归并
- python
- fold
---

在学习javascript和python的过程中，我们通常会接触到`map`、`filter`、`reduce`之类的一等公民高阶函数。理解`map`和`filter`是相对简单的事情，但理解`reduce`的话还是需要一番推敲。正值十一假期，今天这篇文章就好好讲讲`reduce`这个东西

我们首先以python为例，看一段`reduce`程序的操作：

<!-- more -->

```python
from functools import reduce
from dataclasses import dataclass


@dataclass
class Stats:
    product: int = 1
    sum: int = 0
    num: int = 0
    avg: float = 0.0
    max: int = -1e9
    min: int = 1e9


def reducer(cur_state, cur_element):
    assert isinstance(cur_state, Stats)
    print('processing element %d, current stats: %s' % (cur_element, cur_state))
    cur_state.num += 1
    cur_state.sum += cur_element
    cur_state.product *= cur_element
    cur_state.avg = float(cur_state.sum) / float(cur_state.num)
    if cur_element > cur_state.max:
        cur_state.max = cur_element
    if cur_element < cur_state.min:
        cur_state.min = cur_element
    return cur_state


def main():
    ints = [1, 5, 2, 3, 4]
    reduced_stats = reduce(reducer, ints, Stats())
    print(reduced_stats)


if __name__ == '__main__':
    main()
```

这段程序里的操作，输入是一组整数，最后输出来的是这组整数的统计数据，比如总和`sum`、积`product`、最大最小值等等。实现这个统计操作，就可以用`reduce`。在`functools`库中，我们可以看到`reduce`的定义：

```python
_initial_missing = object()

def reduce(function, sequence, initial=_initial_missing):
    """
    reduce(function, sequence[, initial]) -> value

    Apply a function of two arguments cumulatively to the items of a sequence,
    from left to right, so as to reduce the sequence to a single value.
    For example, reduce(lambda x, y: x+y, [1, 2, 3, 4, 5]) calculates
    ((((1+2)+3)+4)+5).  If initial is present, it is placed before the items
    of the sequence in the calculation, and serves as a default when the
    sequence is empty.
    """

    it = iter(sequence)

    if initial is _initial_missing:
        try:
            value = next(it)
        except StopIteration:
            raise TypeError("reduce() of empty sequence with no initial value") from None
    else:
        value = initial

    for element in it:
        value = function(value, element)

    return value

try:
    from _functools import reduce
except ImportError:
    pass
```

这段代码简单易懂，我们可以看到`reduce`函数需要一个初始值`initial`，并定义一个会变化的当前值`value`，然后会在遍历我们定义的`sequence`序列的过程中，不断用`function`（叫成`reducer`更加贴切）依据当前遍历到的元素`element`来更新当前值`value`（的内部状态），并在最后返回最终的`value`。

所以很显然，`reduce`这个函数，针对一个特定的`sequence`，返回值应当反映这个`sequence`的某样（些）属性。这便是`reduce`的意义所在了。

学过javascript的同学，会经常在网上资料看到`reduce`的翻译叫做`归并`，个人认为`归并`这个词已经翻译的非常贴切了，一时间也找不到更好的信达雅的表达。当然如果我们去检索英文百科，甚至还可以了解到更多的信息。

`reduce`是函数式编程的一个代表。我们检索[函数式编程的维基百科](https://en.wikipedia.org/wiki/Functional_programming)，里面可以跳到`reduce`的百科，我们发现其实会跳到[另一个单词的百科](https://en.wikipedia.org/wiki/Fold_(higher-order_function))，叫做`fold`

从`fold`以及衍生词汇`reduce`、`accumulate`、`aggregation`可以看到，这类操作其实用中文翻译除了叫`归并`以外，叫`累积`、`聚合`也不过分（嗯这里又可以看到我们的老朋友mongodb，`aggregation`跟`accumulate`关键词都上架了），都是代表着一种`遍历所有元素值，不管合并计算结果`的运算操作。`fold`反过来叫做`unfold`，对应的也是[另一个单词的百科](https://en.wikipedia.org/wiki/Anamorphism)，叫做`Anamorphism`。`Anamorphism`本意是`岩石变性`、`渐变`，但在计算机领域，作为和`fold`相反的运算方式，是一个会不断根据当前值来生成下一个值，从而`展开`出来一个`sequence`的生成器`generator`（所以这种运算通俗的说，就翻译为`展开`即可，跟`unfold`也很搭）。我们熟悉的斐波那契数列，就可以用`unfold`/`Anamorphism`代表的运算方式生成。初始值为（0，1），根据（0，1）生成下一个数字1，根据（1，1）生成下一个数字2。这样不断`展开`下去，我们就可以得到特定长度的斐波那契数列了。
