---
title: 【Lua杂谈】犹豫就会败北——元表metatable解析
date: 2019/06/12 22:58:05
categories:
- Lua杂谈
tags:
- lua
- 元表
- 面向对象
- 继承
- 原型模式
---

## 前言

在lua的学习过程当中，元表metatable的概念及用法是常见的障碍之一

元表，在其它lua杂谈等都提到过，是一种描述lua数据的属性以及行为的表。虽然官方给了set、account等例子详细讲解了metatable，但总还是缺乏些提炼。为了干翻这个痛点，这次，果断强上metatable的精髓。毕竟，犹豫就会败北~

## 元表有什么？

我们首先就会有疑问：通过哪些属性指标，可以描述lua的数据呢？通过[官方手册](https://www.lua.org/manual/5.3/manual.html#2.4)，我们可以很容易地找到答案。

在lua中，我们把元表中的key，也就是描述数据的属性指标，称之为event

我们可以把所有的event分为两组（括号中代表lua里的语法）：

1. 描述其基础性质的：
   - 属性索引：`__index`，`__newindex`
   - 长度：`__len(#)`
   - 函数形式：`__call`
   - 字符串形式：`__tostring`

2. 描述其运算的：
   - 普通运算：`__add(加+)`，`__sub(减-)`，`__mul(乘*)`，`__div(除/)`，`__mod(模%)`，`__pow(乘方^)`，`__unm(负-)`，`__idiv(取整除//)`
   - 位运算：`__band(与&)`，`__bor(或|)`，`__bxor(异或~)`，`__bnot(非~)`，`__shl(左移<<)`，`__shr(右移>>)`
   - 关系运算：`__concat(联结..)`，`__eq(全等==)`，`__lt(小于<)`，`__lte(小于等于<=)`

## 元表怎么用？

先来看一段程序吧~

<!-- more -->

```lua
local mt = {
    __band = function (a, b)
        print(a)
        print(b)
        return 12345
    end,
    __call = function (x)
        print(x)
    end,
}

local t = setmetatable({}, mt)
local s = debug.setmetatable("666", mt)

print("\n-------------------------------------------------\n")
local i = debug.setmetatable(t & s, mt)
print("\n-------------------------------------------------\n")
i()
```

打印出来什么呢？就是这个~

```plain
-------------------------------------------------

table: 0000000000dca020
666

-------------------------------------------------

12345
```

这其中如何进行？首先我们看代码，表mt表示元表，定义了以下数据交互行为:

- “逻辑与”操作band，变成把逻辑与的两边打印出来，不管两边是啥，然后返回数值12345
- “函数调用”操作call，变成直接把函数调用者打印出来，不管调用者到底是啥数据类型

然后就可以开始骚操作了~在lua中，一般只有table类型的数据可以setmetatable，但是如果我们调用debug库的话，就可以为任意类型的数据设置元表。所以，我们先可以试试字符串与表之间的交互~

新建设置了元表的空表t与"666"字符串s，然后，为它们设置元表。这样它们就可以交互啦~

当执行`local i = t & s`的时候，在`t & s`的操作中，根据元表`__band`定义，会把t跟s都print出来，然后返回12345给i。i是一个数字，但仍然可以被设置上元表。然后再试试看调用i的操作`i()`，根据元表的`__call`逻辑，就会打印出i来了。

很黑科技吧~

## 元表&面向对象

元表最常见的用途是lua的面向对象编程，具体而言，则是采用原型模式进行。新建的对象实例初始化时继承原型的方法，并且在修改属性的过程中不影响原型的变化。

我们看看原型类的实现：

```lua
local prototype = {
    tag = "PROTOTYPE",
    value = "hello world",
}

function prototype:print()
    for k, v in pairs(self) do
        print(k .. ": " .. tostring(v))
    end
end

function prototype:new(o)
    o = o or {}
    return setmetatable(o, {
        __index = self,
        -- __newindex = function (t, k, v) rawset(t, k, v) end
    })
end

return setmetatable(prototype, { __call = prototype.new })
```

在原型类的原表中，把__call设置为构造函数new，这也符合我们一贯的调用构造函数的习惯。对于每一个新实例，我们将元表中的__index设置为prototype自己，将__newindex设定为rawset机制。

__index表示属性查找索引/方法，可以是一个表，也可以是一个函数。对于一个表而言，如果要查找x属性但在表里没有的话，就会调用元表的__index进行查找。因此，在新实例中，__index理所当然地设置为原型表prototype

__newindex表示更新属性的机制，可以是一个另外单独的表，也可以是一个函数。如果设置成另外单独的表，则新的属性跟值都会设到另外的表上；如果是一个函数，对于表实例而言，则默认为触发table本身的rawset逻辑，将新的键值对设到该实例上。table的rawset逻辑不会反过来触发newindex，因此不会造成stack overflow

接下来我们可以看基于原型的实例：

```lua
local prototype = require "prototype"

print("\n---------------- init table -----------------\n")
local t = prototype({ tag = "TABLE" })
t:print()

print("\n---------------- init prototype -----------------\n")
getmetatable(t).__index:print()

print("\n--------------  modified table  ---------------\n")

t.new_value = "new name"
t.value = "jaja"
t.tag = "NEWTABLE"
t:print()

print("\n--------------  modified? prototype  ---------------\n")

getmetatable(t).__index:print()
```

我们初始化一个基于prototype的实例，并且修改其中的值，再反过来看原型的值，打印如下：

```plain
---------------- init table -----------------

tag: TABLE

---------------- init prototype -----------------

value: hello world
print: function: 0000000002a60940
new: function: 0000000002a60af0
tag: PROTOTYPE

--------------  modified table  ---------------

tag: NEWTABLE
new_value: new name
value: jaja

--------------  modified? prototype  ---------------

value: hello world
print: function: 0000000002a60940
new: function: 0000000002a60af0
tag: PROTOTYPE
```

很幸运，正如我们所期望的那样！

## 总结

元表metatable，听起来拗口，但用起来非常灵活~

不仅是lua，像python，也有类似的操作

在实际lua编程的时候，可得多尝试喔~
