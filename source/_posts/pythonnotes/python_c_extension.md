---
title: 【Python随笔】用C++编写Python的扩展模块
date: 2021/10/05 00:44:59
categories:
- Python随笔
tags:
- python
- C++
- python扩展模块
- Visual Studio
- cplayground
---

近期笔者在研究python内部部分模块的实现机理，研究着研究着就开始硬刚C源码了。想着先前工作或是日常也没有体验过用C++编写python库，于是就刚好学习了一下。

用C或者C++编写python的扩展库，建议用Visual Studio宇宙第一IDE，一来能够同时支持python跟C，二来调试功能非常强大。入门上手的话，可以参考下面的文档：

- [官网文档：扩展和嵌入 Python 解释器](https://docs.python.org/zh-cn/3/extending/index.html)
- [VS文档：Create a C++ extension for Python](https://docs.microsoft.com/en-us/visualstudio/python/working-with-c-cpp-python-in-visual-studio?view=vs-2019)

编写的库叫做`cplayground`，只包含一个hack函数`tuple_setitem`——强行设置tuple的元素（python默认是不支持的）。我们可以来看这样的python扩展用C++该如何实现：

<!-- more -->

首先参考上面的VS文档`Create a C++ extension for Python`，部署基础环境，一个Solution里需要包含用于测试的Python Project以及用来编写扩展的C++ Project。环境部署有几个要点需要注意：

- 由于是编写扩展，需要编译为dll，文件后缀名为.pyd
- 确认下libs有没有debug库，没有的话Preprocessor跟Code Generation的设置都不能带debug
- python项目的Debug设置里，解释器参数加上`-i`，且启用native code debugging，这样才能在python跟c代码打断点调试
- 可以写一个最简的框架先尝试build成功，并且能顺利装到对应python的packages里，跑通整个流程先
  - `setup.py`中注意模块名字要全部对应上

值得一提的是，如果VS没有预装python发行版本，VS自带的python环境管理模块也能检测到你以前另外安装的python，所以不用担心python环境方面的问题。

搭好整个框架流程之后，我们可以实现`tuple_setitem`具体的逻辑了。整个cpp代码如下：

```cpp
// cplayground.cpp

#define PY_SSIZE_T_CLEAN
#include <Python.h>


/* tuple_setitem: a hack method to set item of tuple */
PyObject*
tuple_setitem(PyObject* self, PyObject* args)
{
    // parse args
    PyObject *tuple, *value;
    int idx;
    if (!PyArg_ParseTuple(args, "OiO", &tuple, &idx, &value))
    {
        Py_RETURN_FALSE;
    }
    
    // check tuple
    if (!PyTuple_Check(tuple))
    {
        PyErr_Format(
            PyExc_TypeError,
            "invalid tuple, %.200s",
            Py_TYPE(tuple)->tp_name
        );
        Py_RETURN_FALSE;
    }
    PyTupleObject* tp = (PyTupleObject*)tuple;

    // handle index below zero
    if (idx < 0)
    {
        idx += PyTuple_GET_SIZE(tp);
    }

    // check index range
    if ((size_t)idx >= (size_t)Py_SIZE(tp))
    {
        PyErr_SetString(
            PyExc_IndexError,
            "tuple index out of range"
        );
        Py_RETURN_FALSE;
    }

    // set value by index
    Py_INCREF(value);
    Py_SETREF(tp->ob_item[idx], value);
    Py_RETURN_TRUE;
}



static PyMethodDef cplayground_methods[] = {
    {
        "tuple_setitem",
        (PyCFunction)tuple_setitem,
        METH_VARARGS,
        "a hack method to set value in tuple"
    },
    { nullptr, nullptr, 0, nullptr }
};

static PyModuleDef cplayground_module = {
    PyModuleDef_HEAD_INIT,
    "cplayground",  // module name
    "a c-python extension for testing",  // module desc
    0,
    cplayground_methods
};

PyMODINIT_FUNC
PyInit_cplayground()
{
    return PyModule_Create(&cplayground_module);
}
```

在模块的cpp实现中，顶头必须要`#include <Python.h>`，之后我们可以把自己需要暴露出去的函数给实现了（这里可以看到模块的主cpp文件能够起到胶水层的作用，如果此时有其它头文件里定义了一系列接口，就可以在这个文件里把这些接口适配为python可识别的函数模式）。实现完成之后，通过`method def`跟`module def`定义接口列表跟模块，然后再在下面定义模块启动函数，一个python的C扩展就诞生了。

那么怎么实现`tuple_setitem`的逻辑呢？我们需要预想下python端如何调用：

```python
import cplayground

tp = (1, 2, 3)
cplayground.tuple_setitem(tp, 0, 'haha')  # 设置第一个元素为字符串'haha'
```

在C层的实现上，`tuple_setitem`的签名是两个参数：**module自己的引用、打包的参数集合**，都是`PyObject*`。

首先第一步是通过`PyArg_ParseTuple`看是否能用对应的模式解包参数。关于参数的模式，可以参考[这个文档](https://docs.python.org/3/c-api/arg.html)。

之后需要对解包的参数再检查，比如检查解出来的`PyObject* tuple`是否真正是`tuple object`，以及计算索引是不是有溢出的情况。

最后通过`Py_SETREF`，就能把传进来的元组的内部元素重置。整个实现过程，其实是参考了`list object`的相关实现，有兴趣的同学可以深入探索一下（预告：在后面的文章里也会提到这个）。

整个小项目都放到了[github](https://github.com/utmhikari/pycext_playground)上，是一个sln。如果要测试的话，clone之后需要注意重新走一遍环境配置的过程，确认配置无误。
