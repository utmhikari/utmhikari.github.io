---
title: 【Python随笔】如何访问类实例里带双下划线的属性
date: 2021/10/06 20:41:24
categories:
- Python随笔
tags:
- python
- 类
- 面向对象
- 编译
- 下划线
---

学过python的我们都知道在python的类实例instance的`__init__`函数里，可以初始化这个instance的属性。属性的命名有许多种，比如有一个例子：

```python
class Student:
    def __init__(self, name, gender, age):
        self.name = name
        self._gender = gender
        self.__age = age
```

这三种属性名分别是：不带下划线、带一个下划线、带两个下划线

假设有一个类`Student`的实例`student`，我们通过访问`student.name`、`student._gender`，是能够获得对应属性值的，但访问`student.__age`却报了如下错误：

<!-- more -->

```text
AttributeError: 'Student' object has no attribute '__age'
```

这是为什么呢？难道在外面就不能访问这个`__age`属性了吗？

首先，要做到访问`__age`属性，最符合编程意图的方法就是加一个与`age`关联的`property`来访问。但本文不采用这种方法，本文提供一个直接访问`__age`属性的方法。

我们可以打印`student.__dict__`，来查看`student`实例的属性表：

```text
{'name': 'haha', '_gender': 'male', '_Student__age': 12}
```

我们发现，属性表里没有`__age`属性，而多了一个`_Student__age`属性。为什么会这样呢？这是因为在代码编译器期有`name mangling`机制，用中文翻译叫做“命名混淆”比较贴切，python编译器识别了带双下划线的类实例属性，就会在前面加一个下划线+类名的前缀，于是属性名就变成了`_Student__age`。

通过访问`student._Student__age`，我们就能得到`__age`属性了。这便是直接访问双下划线属性的方法。
