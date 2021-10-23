---
title: 【Medium Python】第二话：dict的keys()返回了什么数据类型？
date: 2021/10/23 17:55:52
categories:
- Medium Python
tags:
- python
- DictView
- dict
- C
- dict_keys
---

在python3里面，我们经常会用`if k in d.keys()`来判断某个key是不是在某个dict里面，或者是用`a_dict.keys() - b_dict.keys()`来获取两个字典之间keys的差集。那么这里就有一个问题，dict的`keys()`返回了什么数据类型呢？

list？set？两者都是错误答案。Don't say so much，打印一下type，发现是这么个数据类型：`<class 'dict_keys'>`

## dict_keys是什么东西？

在python dict数据结构定义中（`dictobject.c`），可以看到`dict_keys`的定义

<!-- more -->

```c
// dictobject.c

PyTypeObject PyDictKeys_Type = {
    PyVarObject_HEAD_INIT(&PyType_Type, 0)
    "dict_keys",                                /* tp_name */
    sizeof(_PyDictViewObject),                  /* tp_basicsize */
    0,                                          /* tp_itemsize */
    /* methods */
    (destructor)dictview_dealloc,               /* tp_dealloc */
    0,                                          /* tp_vectorcall_offset */
    0,                                          /* tp_getattr */
    0,                                          /* tp_setattr */
    0,                                          /* tp_as_async */
    (reprfunc)dictview_repr,                    /* tp_repr */
    &dictviews_as_number,                       /* tp_as_number */
    &dictkeys_as_sequence,                      /* tp_as_sequence */
    0,                                          /* tp_as_mapping */
    0,                                          /* tp_hash */
    0,                                          /* tp_call */
    0,                                          /* tp_str */
    PyObject_GenericGetAttr,                    /* tp_getattro */
    0,                                          /* tp_setattro */
    0,                                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,/* tp_flags */
    0,                                          /* tp_doc */
    (traverseproc)dictview_traverse,            /* tp_traverse */
    0,                                          /* tp_clear */
    dictview_richcompare,                       /* tp_richcompare */
    0,                                          /* tp_weaklistoffset */
    (getiterfunc)dictkeys_iter,                 /* tp_iter */
    0,                                          /* tp_iternext */
    dictkeys_methods,                           /* tp_methods */
    0,
};
```

`dict_keys`数据结构的size，是以`_PyDictViewObject`为准的。`_PyDictViewObject`从语义上看是dict的一个视图，从逻辑上看只包含了一个对应dict的指针

```c
// dictobject.h

typedef struct {
    PyObject_HEAD
    PyDictObject *dv_dict;
} _PyDictViewObject;
```

如何理解`DictView`的设计？其实这种相当于一个dict实例的代理（Agent/Proxy），用户（开发者）侧请求对应的操作（in、运算符等），代理侧来给出一个最有效率的方案。举一些例子：

### in操作

in涉及到`for k in d.keys()`跟`has_key = (k in d.keys())`两种形式，对应迭代遍历跟包含两种操作。
`for k in d.keys()`操作对应的是`PyDictKeys_Type`里的`dictkeys_iter`函数，返回了这个`DictView`视图对应的dict的key的iterator，类型为`PyDictIterKey_Type`。在迭代遍历时候，会一直调用`PyDictIterKey_Type`里定义的`dictiter_iternextkey`执行迭代过程中的next操作，从而一个个地获得dict里所有key。

```c
// dictobject.c

// dict的key的iterator的定义，这里只节选一部分
PyTypeObject PyDictIterKey_Type = {
    "dict_keyiterator",                         /* tp_name */
    sizeof(dictiterobject),                     /* tp_basicsize */
    PyObject_SelfIter,                          /* tp_iter */
    (iternextfunc)dictiter_iternextkey,         /* tp_iternext */
}
```

`has_key = (k in d.keys())`对应的是包含操作，在`PyDictKeys_Type`里面，对应的是`dictkeys_as_sequence`的`dictkeys_contains`回调。在上一讲[list可变、tuple不可变](https://utmhikari.top/2021/10/17/mediumpython/i/)中已经提到，python里面实现对特定数据的多种操作，实际上会尝试将数据看成sequence、mapping等形式，执行对应数据形式中定义的回调函数，而这里便是将keys看作是sequence，执行`sq_contains`对应的回调，表示一个是否包含的判断。`dictkeys_contains`实质上调用的是dict自己的contains操作，也就是说`k in d.keys()`和`k in d`这两种写法，实质上是等价的

### 运算符操作

dict_keys支持多种运算符操作。比如我们在对比作为counter的dict时（不是内置的Counter类），会用keys相减的方式来得到两次统计里新增/删除的key。相减的操作，比如`a.keys() - b.keys()`，会执行将keys看作为number时的`dictviews_sub`函数。在函数内部的实现里，会首先将`a.keys()`转化为一个set，然后调用set数据结构的`difference_update`函数，逐步remove掉右侧`b.keys()`里面的元素。

```c
// dictobject.c

static PyObject*
dictviews_sub(PyObject *self, PyObject *other)
{
    PyObject *result = dictviews_to_set(self);
    if (result == NULL) {
        return NULL;
    }

    _Py_IDENTIFIER(difference_update);
    PyObject *tmp = _PyObject_CallMethodIdOneArg(
            result, &PyId_difference_update, other);
    if (tmp == NULL) {
        Py_DECREF(result);
        return NULL;
    }

    Py_DECREF(tmp);
    return result;
}
```

值得注意的是，`dictviews_sub`内部指定了一个标识符`PyId_difference_update`，通过`_PyObject_CallMethodIdOneArg`函数去调用`result`实例里标识为`PyId_difference_update`的函数，入参为`other`。这样调用接口的方式，在python里称之为[vectorcall](https://www.python.org/dev/peps/pep-0590/)，是3.9完全应用的cpython的特性，相对于以前的版本，显著优化了cpython内部不同数据结构间函数调用的效率。有兴趣的同学可以深入了解。

如果是类似=、>、<之类的操作，dict_keys也是支持的，我们可以在`dictview_richcompare`函数中看到这些比较符对应的计算方式：

```c
// dictobject.c

static PyObject *
dictview_richcompare(PyObject *self, PyObject *other, int op)
{
    Py_ssize_t len_self, len_other;
    int ok;
    PyObject *result;

    assert(self != NULL);
    assert(PyDictViewSet_Check(self));
    assert(other != NULL);

    if (!PyAnySet_Check(other) && !PyDictViewSet_Check(other))
        Py_RETURN_NOTIMPLEMENTED;

    len_self = PyObject_Size(self);
    if (len_self < 0)
        return NULL;
    len_other = PyObject_Size(other);
    if (len_other < 0)
        return NULL;

    ok = 0;
    switch(op) {

    case Py_NE:
    case Py_EQ:
        if (len_self == len_other)
            ok = all_contained_in(self, other);
        if (op == Py_NE && ok >= 0)
            ok = !ok;
        break;

    case Py_LT:
        if (len_self < len_other)
            ok = all_contained_in(self, other);
        break;

      case Py_LE:
          if (len_self <= len_other)
              ok = all_contained_in(self, other);
          break;

    case Py_GT:
        if (len_self > len_other)
            ok = all_contained_in(other, self);
        break;

    case Py_GE:
        if (len_self >= len_other)
            ok = all_contained_in(other, self);
        break;

    }
    if (ok < 0)
        return NULL;
    result = ok ? Py_True : Py_False;
    Py_INCREF(result);
    return result;
}
```

如果两个dict的keys相等，则这两组keys需要长度一样，并且包含相同的元素（类似于set相等）
如果是比大小，比如`a.keys()`要比`b.keys()`大的话，除了`a.keys()`长度比`b.keys()`大之外，还需要`a.keys()`包含`b.keys()`所有的元素才行。所以大小于号主要体现的是包含/被包含的关系。

## View概念的其它应用

在dict里，除了`keys()`之外，dict的`values()`、`items()`，返回的实际上也是`DictView`的视图结构，定义的方式也基本上相似，但也有少许区别。比如`values()`，由于没有指定`tp_richcompare`，所以无法将两组`values`进行大小或==的比较（都会返回false）
​

在python里有很多地方应用了视图的概念/手法。如果硬要套View这个单词的话，就还有这么一个地方应用到了，叫做[memoryview](https://docs.python.org/zh-cn/3/c-api/memoryview.html)。`memoryview`在业务代码中不常用，主要的作用是提供一块内存的“代理”，让调用方安全地对一个数据实例的内存进行信息读取及管理操作。比如我们对各种数据做`pickle.dumps`序列化后，通过`memoryview`，就能看到序列化后的数据在内存里的组成：

```python
def memoryview_test():
    s = '1234567890'
    mem_view = memoryview(pickle.dumps(s))
    print(len(mem_view))
    print([chr(item) for item in mem_view])
    s = ['1234', '56', '7890']
    mem_view = memoryview(pickle.dumps(s))
    print(len(mem_view))
    print([chr(item) for item in mem_view])
    s = ['12345', '67890']
    mem_view = memoryview(pickle.dumps(s))
    print(len(mem_view))
    print([chr(item) for item in mem_view])
    
"""
25
[
    '\x80', '\x04', '\x95',
    '\x0e', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x8c', '\n',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '\x94', '.'
]
20
[
    '\x80', '\x04', '\x95',
    '\t', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x8c', '\x05',
    '5', '4', '3', '2', '1', '\x94', '.'
]
35
[
    '\x80', '\x04', '\x95', '\x18', 
    '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', ']', '\x94', '(', 
    '\x8c', '\x04', '1', '2', '3', '4', 
    '\x94', '\x8c', '\x02', '5', '6', 
    '\x94', '\x8c', '\x04', '7', '8', '9', '0', 
    '\x94', 'e', '.'
]
32
[
    '\x80', '\x04', '\x95', '\x15', 
    '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', ']', '\x94', '(', 
    '\x8c', '\x05', '1', '2', '3', '4', '5', 
    '\x94', '\x8c', '\x05', '6', '7', '8', '9', '0', 
    '\x94', 'e', '.'
]
"""
```
