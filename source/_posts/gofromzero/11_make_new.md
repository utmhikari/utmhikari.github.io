---
title: 【从零单排Golang】第十一话：make和new的区别和用法
date: 2023/05/10 23:49:18
categories:
- 从零单排Golang
tags:
- Golang
- make
- new
- 初始化
- 零值
---

在Golang当中，对于常用数据结构的初始化方式，通常有2种：make跟new。这两种初始化方法用途不同，效果不同。本篇文章就来详细讲一下make和new具体都怎么用，在什么场景下会用上。

首先来看make。比起new，make所用到的场景非常特定，一般没法直接避开。我们看下面的代码例子：

```go
func TestMake(t *testing.T) {
    var m = make([]int, 5, 10)
    t.Logf("[Make] m is %v, len: %v, cap: %v", m, len(m), cap(m))
}

func TestNoMake(t *testing.T) {
    var m [5]int
    t.Logf("[NoMake] m is %v, len: %v, cap: %v", m, len(m), cap(m))
}
```

两个代码似乎都会初始化长度为5的“列表”m，但其实两个m的内在构造并不相同。实际上会出现如下的效果：

<!-- more -->

- TestMake构造出来长度为5，容量为10，可变长度的slice
- TestNoMake构造出来长度为5，容量为5，不可变长度的array

这就是其中的不同了，通过两种方式，实际会构造出来两种数据结构。我们常用的`var m []int`方法构造出来的，其实是可变长度的slice，可以通过append添加元素。通过make，针对slice、map、channel这三个数据结构，我们可以通过make给这些数据结构实例预设大小或容量，从而能够快速容纳一部分数据。对于需要利用这些容器类数据结构，预加载数据的场景，就可以用make来操作。

而new和make则完全不同，new的作用，主要是返回某个类型的“零值”的指针。我们来看下面的两个testcase：

```go
func TestNew(t *testing.T) {
    var i = new(int)
    t.Logf("[New] value of i is %v", *i)
}

func TestNoNew(t *testing.T) {
    var i *int
    t.Logf("[NoNew] value of i is %v", *i)
}
```

实际上出来的是如下的效果：

- TestNew构造出来指向0（int的零值）的指针，正常打印
- TestNoNew构造出来nil指针，panic掉

可以看到，如果我们希望在某些初始化函数里，返回某些基础数据类型，或者是struct的零值的指针，用new都可以做到，无需nil检查。尤其针对struct的零值的指针，在很多场景都能够用上。随便举一个测试协议序列化的例子：

```go
// bytes.Buffer
type Buffer struct {
    buf      []byte // contents are the bytes buf[off : len(buf)]
    off      int    // read at &buf[off], write at &buf[len(buf)]
    lastRead readOp // last read operation, so that Unread* can work correctly.
}

func TestMarshalText(t *testing.T) {
    buf := new(bytes.Buffer)  // 非nil零值指针
    if err := proto.MarshalText(buf, newTestMessage()); err != nil {
        t.Fatalf("proto.MarshalText: %v", err)
    }
    s := buf.String()
    if s != text {
        t.Errorf("Got:\n===\n%v===\nExpected:\n===\n%v===\n", s, text)
    }
}
```
