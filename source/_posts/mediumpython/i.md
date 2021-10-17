---
title: 【Medium Python】第一话：为什么list“可变”，而tuple“不可变”？
date: 2021/10/17 17:55:52
categories:
- Medium Python
tags:
- python
- 源码分析
- list
- tuple
- 元组
---

## 前言

python面试有一道很基础的问题：list（列表）和tuple（元组）有什么不同？基本上只要背过题库的同学都知道，list（里面的元素）是可变的，tuple（里面的元素）是不可变的。

我们尝试在python解释器中改变tuple的元素（赋另一个值），会有以下的表现：

```python
def tuple_check():
    tp = ('123', 123)
    tp[1] = 13
    
"""
Traceback (most recent call last):
  File "H:/Projects/Python/playground/main.py", line 20, in <module>
    tuple_check()
  File "H:/Projects/Python/playground/main.py", line 10, in tuple_check
    tp[2] = 13
TypeError: 'tuple' object does not support item assignment
"""
```

可以看到赋值操作报错，tuple不支持再次赋值，体现了其“不可变”的特性。

但是，不支持赋值/不可变的原因，到底是什么呢？不是说不支持就不支持吧！难道也没有支持的可能？

这个问题要给出清晰的答案可并不容易，如果你直接检索网上资料的话，会发现很多文章都在说重复的话，没有什么深入的挖掘，导致这个问题无从解释。于是，今天这篇文章，就给大家把这个问题讲的干脆一点。

以及，看完这篇文章之后，网上那些车轱辘话大家也就没有必要再看了。

<!-- more -->

## 赋值操作的源码分析

从官网的[Python-Source-Release](https://www.python.org/downloads/source/)页面中，我们能够下载到Python各个版本的源代码（笔者下载了3.9.7）。在源码的`PCBuild`文件夹下，有Visual Studio专属的`pcbuild.sln`项目文件，打开它就能看到python各个库的源代码的集合，以及各种文档和编译构建脚本。准备好了环境，就可以开始研究了。

以上述的赋值操作为例，通过检索`object does not support item assignment`字样，我们可以定位到对应的函数：

```c
// Objects/abstract.c

int
PyObject_SetItem(PyObject *o, PyObject *key, PyObject *value)
{
    PyMappingMethods *m;

    if (o == NULL || key == NULL || value == NULL) {
        null_error();
        return -1;
    }
    m = Py_TYPE(o)->tp_as_mapping;
    if (m && m->mp_ass_subscript)
        return m->mp_ass_subscript(o, key, value);

    if (Py_TYPE(o)->tp_as_sequence) {
        if (_PyIndex_Check(key)) {
            Py_ssize_t key_value;
            key_value = PyNumber_AsSsize_t(key, PyExc_IndexError);
            if (key_value == -1 && PyErr_Occurred())
                return -1;
            return PySequence_SetItem(o, key_value, value);
        }
        else if (Py_TYPE(o)->tp_as_sequence->sq_ass_item) {
            type_error("sequence index must be "
                       "integer, not '%.200s'", key);
            return -1;
        }
    }

    type_error("'%.200s' object does not support item assignment", o);
    return -1;
}
```

`PyObject_SetItem`函数涉及到`PyObject *o`、`PyObject* key`、`PyObject *value`三个入参，分别对应我们的tuple实例、索引以及待赋的值。这个函数是一个通用的接口，我们可以看到函数内首先尝试将实例o看作为`mapping`或者是`sequence`（`tp_as_mapping`、`tp_as_sequence`）。如果能作为`mapping`，就看是否能执行`mp_ass_subscript`回调实现赋值；如果作为`sequence`，会检查`key`并尝试执行`PySequence_SetItem`函数，在这个函数里也会尝试执行`Py_TYPE(o)->tp_as_sequence->sq_ass_item`回调实现赋值。
​

在研究tuple之前，我们可以通过对list实例进行断点调试，追踪list赋值操作的执行链路。断点直接断在`PyObject_SetItem`里面即可，测试代码如下：

```python
lst = [1, 2, 3]
lst[2] = 5
```

不出意外的话执行到第二行就会切到debug，一行一行下去，可以看到list实例赋值能够走到这里：

```python
m = Py_TYPE(o)->tp_as_mapping;
if (m && m->mp_ass_subscript)
    return m->mp_ass_subscript(o, key, value);
```

step into进去，可以看到list实例作为`mapping`的`mp_ass_subscript`回调，对应的是`list_ass_subscript`函数:

```c
// Objects/listobject.c

static int
list_ass_subscript(PyListObject* self, PyObject* item, PyObject* value)
{
    if (_PyIndex_Check(item)) {
        Py_ssize_t i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if (i == -1 && PyErr_Occurred())
            return -1;
        if (i < 0)
            i += PyList_GET_SIZE(self);
        return list_ass_item(self, i, value);
    }
    else if (PySlice_Check(item)) {
        // 这里是对切片赋值，[a:b]这种。太长了先忽略掉= =
        return -1;
    }
    else {
        PyErr_Format(PyExc_TypeError,
                     "list indices must be integers or slices, not %.200s",
                     Py_TYPE(item)->tp_name);
        return -1;
    }
}

static int
list_ass_item(PyListObject *a, Py_ssize_t i, PyObject *v)
{
    if (!valid_index(i, Py_SIZE(a))) {
        PyErr_SetString(PyExc_IndexError,
                        "list assignment index out of range");
        return -1;
    }
    if (v == NULL)
        return list_ass_slice(a, i, i+1, v);
    Py_INCREF(v);
    Py_SETREF(a->ob_item[i], v);
    return 0;
}
```

`list_ass_subscript`函数会判断索引`key`的合法性并转换负值索引，然后调用`list_ass_item`处理赋值操作。`list_ass_item`也会再次检查索引边界，然后在list实例对应索引的位置赋新值，并调整引用计数。这样，list赋值操作就完成了。

## tuple为什么不可变

list可以对其中的元素赋值，tuple不行。从源码的角度，list能够作为`mapping`，有`list_ass_subscript`函数用于对元素赋值，那tuple呢？我们同样可以断tuple的赋值操作，可以看到最终还是落到`PyObject_SetItem`的“`object does not support item assignment`”一行
​

打开list这个类在C层的源代码，我们能够看到list这个数据类型的定义：

```c
// Objects/listobject.c

PyTypeObject PyList_Type = {
    PyVarObject_HEAD_INIT(&PyType_Type, 0)
    "list",
    sizeof(PyListObject),
    0,
    (destructor)list_dealloc,                   /* tp_dealloc */
    0,                                          /* tp_vectorcall_offset */
    0,                                          /* tp_getattr */
    0,                                          /* tp_setattr */
    0,                                          /* tp_as_async */
    (reprfunc)list_repr,                        /* tp_repr */
    0,                                          /* tp_as_number */
    &list_as_sequence,                          /* tp_as_sequence */
    &list_as_mapping,                           /* tp_as_mapping */
    PyObject_HashNotImplemented,                /* tp_hash */
    0,                                          /* tp_call */
    0,                                          /* tp_str */
    PyObject_GenericGetAttr,                    /* tp_getattro */
    0,                                          /* tp_setattro */
    0,                                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC |
        Py_TPFLAGS_BASETYPE | Py_TPFLAGS_LIST_SUBCLASS, /* tp_flags */
    list___init____doc__,                       /* tp_doc */
    (traverseproc)list_traverse,                /* tp_traverse */
    (inquiry)_list_clear,                       /* tp_clear */
    list_richcompare,                           /* tp_richcompare */
    0,                                          /* tp_weaklistoffset */
    list_iter,                                  /* tp_iter */
    0,                                          /* tp_iternext */
    list_methods,                               /* tp_methods */
    0,                                          /* tp_members */
    0,                                          /* tp_getset */
    0,                                          /* tp_base */
    0,                                          /* tp_dict */
    0,                                          /* tp_descr_get */
    0,                                          /* tp_descr_set */
    0,                                          /* tp_dictoffset */
    (initproc)list___init__,                    /* tp_init */
    PyType_GenericAlloc,                        /* tp_alloc */
    PyType_GenericNew,                          /* tp_new */
    PyObject_GC_Del,                            /* tp_free */
    .tp_vectorcall = list_vectorcall,
};

static PyMappingMethods list_as_mapping = {
    (lenfunc)list_length,
    (binaryfunc)list_subscript,
    (objobjargproc)list_ass_subscript
};

typedef struct {
    lenfunc mp_length;
    binaryfunc mp_subscript;
    objobjargproc mp_ass_subscript;
} PyMappingMethods;
```

可以看到，在list类型定义中，`tp_as_mapping->list_as_mapping`已经包含了`PyMappingMethods`所定义的`mp_length`、`mp_subscript`以及`mp_ass_subscript`三个回调，而最后一个就是赋值操作所对应的回调。反观tuple的类型定义，这一块是缺失的：

```c
// Objects/listobject.c

PyTypeObject PyTuple_Type = {
    PyVarObject_HEAD_INIT(&PyType_Type, 0)
    "tuple",
    sizeof(PyTupleObject) - sizeof(PyObject *),
    sizeof(PyObject *),
    (destructor)tupledealloc,                   /* tp_dealloc */
    0,                                          /* tp_vectorcall_offset */
    0,                                          /* tp_getattr */
    0,                                          /* tp_setattr */
    0,                                          /* tp_as_async */
    (reprfunc)tuplerepr,                        /* tp_repr */
    0,                                          /* tp_as_number */
    &tuple_as_sequence,                         /* tp_as_sequence */
    &tuple_as_mapping,                          /* tp_as_mapping */
    (hashfunc)tuplehash,                        /* tp_hash */
    0,                                          /* tp_call */
    0,                                          /* tp_str */
    PyObject_GenericGetAttr,                    /* tp_getattro */
    0,                                          /* tp_setattro */
    0,                                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC |
        Py_TPFLAGS_BASETYPE | Py_TPFLAGS_TUPLE_SUBCLASS, /* tp_flags */
    tuple_new__doc__,                           /* tp_doc */
    (traverseproc)tupletraverse,                /* tp_traverse */
    0,                                          /* tp_clear */
    tuplerichcompare,                           /* tp_richcompare */
    0,                                          /* tp_weaklistoffset */
    tuple_iter,                                 /* tp_iter */
    0,                                          /* tp_iternext */
    tuple_methods,                              /* tp_methods */
    0,                                          /* tp_members */
    0,                                          /* tp_getset */
    0,                                          /* tp_base */
    0,                                          /* tp_dict */
    0,                                          /* tp_descr_get */
    0,                                          /* tp_descr_set */
    0,                                          /* tp_dictoffset */
    0,                                          /* tp_init */
    0,                                          /* tp_alloc */
    tuple_new,                                  /* tp_new */
    PyObject_GC_Del,                            /* tp_free */
    .tp_vectorcall = tuple_vectorcall,
};

static PySequenceMethods tuple_as_sequence = {
    (lenfunc)tuplelength,                       /* sq_length */
    (binaryfunc)tupleconcat,                    /* sq_concat */
    (ssizeargfunc)tuplerepeat,                  /* sq_repeat */
    (ssizeargfunc)tupleitem,                    /* sq_item */
    0,                                          /* sq_slice */
    0,                                          /* sq_ass_item */
    0,                                          /* sq_ass_slice */
    (objobjproc)tuplecontains,                  /* sq_contains */
};

static PyMappingMethods tuple_as_mapping = {
    (lenfunc)tuplelength,
    (binaryfunc)tuplesubscript,
    0
};
```

在`PyMappingMethods`中，tuple作为`mapping`没有指定`mp_ass_subscript`，作为`sequence`也没有指定`sq_ass_item`、`sq_ass_slice`。所以自然而然，原生不支持赋值操作
​

所以，list元素可变而tuple元素不可变，要解释这个问题可以这样阐述：**tuple作为`mapping`或者`sequence`，没有指定赋值操作的回调函数，所以其元素不可变。而list有对应的操作回调支持，所以可变。**
​

## tuple的元素能够“可变”吗？

当然可以，但是需要魔改Python源代码。我们可以仿写`list_ass_subscript`去实现tuple的赋值操作。

```c
// Objects/tupleobject.c

// =========================== 以下是魔改代码 =============================

static int
tuple_ass_item(PyTupleObject* a, Py_ssize_t i, PyObject* v)
{
    if (!((size_t)i < (size_t)Py_SIZE(a)))
    {
        PyErr_SetString(PyExc_IndexError,
            "tuple assignment index out of range");
        return -1;
    }
    if (v == NULL)
    {
        PyErr_SetString(PyExc_IndexError,
            "tuple assignment does not support null value");
        return -1;
    }
    Py_INCREF(v);
    Py_SETREF(a->ob_item[i], v);
    return 0;
}

static int
tuple_ass_subscript(PyTupleObject* self, PyObject* item, PyObject* value)
{
    if (_PyIndex_Check(item))
    {
        Py_ssize_t i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if (i == -1 && PyErr_Occurred())
        {
            return -1;
        }
        if (i < 0)
        {
            i += PyTuple_GET_SIZE(self);
        }
        return tuple_ass_item(self, i, value);
    }
    else
    {
        PyErr_Format(PyExc_TypeError,
            "tuple index must be integer! not %.200s",
            Py_TYPE(item)->tp_name);
        return -1;
    }
}

// =========================== 以上是魔改代码 =============================

static PyMappingMethods tuple_as_mapping = {
    (lenfunc)tuplelength,
    (binaryfunc)tuplesubscript,
    // 0
    (objobjargproc)tuple_ass_subscript  // 这里原来是0，现在得是tuple_ass_subscript
};
```

我们就加上tuple作为`mapping`时候的赋值操作即可，代码逻辑也和list的基本一样。编译新的python试试看吧

```python
tp = (1, 2, 3)
tp[2] = 5
print(tp)  # (1, 2, 5) 
```
