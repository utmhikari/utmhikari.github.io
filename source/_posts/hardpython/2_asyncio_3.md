---
title: 【Hard Python】【第二章-异步IO】3、async/await的源码实现
date: 2022/02/26 19:08:23
categories:
- Hard Python
tags:
- python
- asyncio
- async
- await
- 异步
---

说完了`asyncio`事件循环是如何运行异步任务的，接下来back to basic，我们一起看看`async`和`await`两个原语具体代表了什么含义。

首先是`async`，`async`通常用来修饰一个函数，表示这个函数会返回一个协程。比如说：

```python
async def _coro_maker(i):
    print(i + 1)


def test_async():
    c = _coro_maker(1)
    asyncio.run(c)
```

对`_coro_maker`进行反编译，得到这样的结果：

<!-- more -->

```text
Disassembly of _coro_maker:
              0 GEN_START                1

  7           2 LOAD_GLOBAL              0 (print)
              4 LOAD_FAST                0 (i)
              6 LOAD_CONST               1 (1)
              8 BINARY_ADD
             10 CALL_FUNCTION            1
             12 POP_TOP
             14 LOAD_CONST               0 (None)
             16 RETURN_VALUE
```

可以看到，函数体内反编译的结果和普通def函数是一致的，唯一的不同是最开始加了`GEN_START`字节码。首先看`GEN_START`的实现。

```c
case TARGET(GEN_START): {
    PyObject *none = POP();
    Py_DECREF(none);
    if (!Py_IsNone(none)) {
        if (oparg > 2) {
            _PyErr_SetString(tstate, PyExc_SystemError,
                "Illegal kind for GEN_START");
        }
        else {
            static const char *gen_kind[3] = {
                "generator",
                "coroutine",
                "async generator"
            };
            _PyErr_Format(tstate, PyExc_TypeError,
                "can't send non-None value to a "
                        "just-started %s",
                        gen_kind[oparg]);
        }
        goto error;
    }
    DISPATCH();
}
```

`GEN_START`对于生成器、协程、`async`生成器都适用。对于`async def`函数其真实含义是调用`send(None)`以触发协程的开始。由于`async def`生成的协程没有`yield`值，因此会报`StopIteration`异常并给出协程的返回值。
​
总的来说，协程是一种特殊的`generator`，具备被`await`的效果。
​
那么接下来，该说`await`了。我们看一组代码示例：

```python
async def _coro_maker(i):
    print(i + 1)
    

async def _test_await():
    c = _coro_maker(1)
    await c


def test_await():
    asyncio.run(_test_await())
```

​
反编译`_test_await`的结果，得到：

```text
Disassembly of _test_await:
              0 GEN_START                1

 27           2 LOAD_GLOBAL              0 (_coro_maker)
              4 LOAD_CONST               1 (1)
              6 CALL_FUNCTION            1
              8 STORE_FAST               0 (c)

 28          10 LOAD_FAST                0 (c)
             12 GET_AWAITABLE
             14 LOAD_CONST               0 (None)
             16 YIELD_FROM
             18 POP_TOP
             20 LOAD_CONST               0 (None)
             22 RETURN_VALUE
```

首先来看`GET_AWAITABLE`，其代码实现如下：

```c
case TARGET(GET_AWAITABLE): {
    PREDICTED(GET_AWAITABLE);
    PyObject *iterable = TOP();
    PyObject *iter = _PyCoro_GetAwaitableIter(iterable);

    if (iter == NULL) {
        int opcode_at_minus_3 = 0;
        if ((next_instr - first_instr) > 2) {
            opcode_at_minus_3 = _Py_OPCODE(next_instr[-3]);
        }
        format_awaitable_error(tstate, Py_TYPE(iterable),
                               opcode_at_minus_3,
                               _Py_OPCODE(next_instr[-2]));
    }

    Py_DECREF(iterable);

    if (iter != NULL && PyCoro_CheckExact(iter)) {
        PyObject *yf = _PyGen_yf((PyGenObject*)iter);
        if (yf != NULL) {
            /* `iter` is a coroutine object that is being
               awaited, `yf` is a pointer to the current awaitable
               being awaited on. */
            Py_DECREF(yf);
            Py_CLEAR(iter);
            _PyErr_SetString(tstate, PyExc_RuntimeError,
                             "coroutine is being awaited already");
            /* The code below jumps to `error` if `iter` is NULL. */
        }
    }

    SET_TOP(iter); /* Even if it's NULL */

    if (iter == NULL) {
        goto error;
    }

    PREDICT(LOAD_CONST);
    DISPATCH();
}
```

`GET_AWAITABLE`做了这样几件事情：

- 通过`_PyCoro_GetAwaitableIter`获取一个`Awaitable`对象的迭代器`iter`
- 检查`iter`是否合法，检查当前`Awaitable`对象是否已经被`await`了
- 将`iter`置于栈顶

`Awaitable`的`iter`到底是什么东西？我们来看`_PyCoro_GetAwaitableIter`的实现：

```c
PyObject *
_PyCoro_GetAwaitableIter(PyObject *o)
{
    unaryfunc getter = NULL;
    PyTypeObject *ot;

    if (PyCoro_CheckExact(o) || gen_is_coroutine(o)) {
        /* 'o' is a coroutine. */
        Py_INCREF(o);
        return o;
    }

    ot = Py_TYPE(o);
    if (ot->tp_as_async != NULL) {
        getter = ot->tp_as_async->am_await;
    }
    if (getter != NULL) {
        PyObject *res = (*getter)(o);
        if (res != NULL) {
            if (PyCoro_CheckExact(res) || gen_is_coroutine(res)) {
                /* __await__ must return an *iterator*, not
                   a coroutine or another awaitable (see PEP 492) */
                PyErr_SetString(PyExc_TypeError,
                                "__await__() returned a coroutine");
                Py_CLEAR(res);
            } else if (!PyIter_Check(res)) {
                PyErr_Format(PyExc_TypeError,
                             "__await__() returned non-iterator "
                             "of type '%.100s'",
                             Py_TYPE(res)->tp_name);
                Py_CLEAR(res);
            }
        }
        return res;
    }

    PyErr_Format(PyExc_TypeError,
                 "object %.100s can't be used in 'await' expression",
                 ot->tp_name);
    return NULL;
}
```

其中有重要的几句代码：

- `if (PyCoro_CheckExact(o) || gen_is_coroutine(o)) return o`
- `getter = ot->tp_as_async->am_await`
- `PyObject *res = (*getter)(o)`

可以知晓，如果对象是协程的话会直接返回，不是协程的话看有无`ot->tp_as_async->am_await`接口支持。如果再追究的话，对于一般的生成器`PyGen_Type`，是没有这个接口的，所以是无法被`await`的。

`GET_AWAITABLE`之后，接下来是`load`了一个`None`，然后`YIELD_FROM`。`YIELD_FROM`实现如下：

```c
case TARGET(YIELD_FROM): {
    PyObject *v = POP();
    PyObject *receiver = TOP();
    PySendResult gen_status;
    if (tstate->c_tracefunc == NULL) {
        gen_status = PyIter_Send(receiver, v, &retval);
    } else {
        // 省略一些代码
    }
    Py_DECREF(v);
    if (gen_status == PYGEN_ERROR) {
        assert (retval == NULL);
        goto error;
    }
    if (gen_status == PYGEN_RETURN) {
        assert (retval != NULL);

        Py_DECREF(receiver);
        SET_TOP(retval);
        retval = NULL;
        DISPATCH();
    }
    assert (gen_status == PYGEN_NEXT);
    /* receiver remains on stack, retval is value to be yielded */
    /* and repeat... */
    assert(f->f_lasti > 0);
    f->f_lasti -= 1;
    f->f_state = FRAME_SUSPENDED;
    f->f_stackdepth = (int)(stack_pointer - f->f_valuestack);
    goto exiting;
}
```

通过`YIELD_FROM`操作，实际上调用了`PyIter_Send(coro, None, &retval)`。我们来看`PyIter_Send`的实现：

```c
PySendResult
PyIter_Send(PyObject *iter, PyObject *arg, PyObject **result)
{
    _Py_IDENTIFIER(send);
    assert(arg != NULL);
    assert(result != NULL);
    if (Py_TYPE(iter)->tp_as_async && Py_TYPE(iter)->tp_as_async->am_send) {
        PySendResult res = Py_TYPE(iter)->tp_as_async->am_send(iter, arg, result);
        assert(_Py_CheckSlotResult(iter, "am_send", res != PYGEN_ERROR));
        return res;
    }
    if (arg == Py_None && PyIter_Check(iter)) {
        *result = Py_TYPE(iter)->tp_iternext(iter);
    }
    else {
        *result = _PyObject_CallMethodIdOneArg(iter, &PyId_send, arg);
    }
    if (*result != NULL) {
        return PYGEN_NEXT;
    }
    if (_PyGen_FetchStopIterationValue(result) == 0) {
        return PYGEN_RETURN;
    }
    return PYGEN_ERROR;
}
```

针对`AwaitableIter`，实际调用了`Py_TYPE(iter)->tp_as_async->am_send(iter, arg, result)`，对应的函数是这个：

```c
static PySendResult
PyGen_am_send(PyGenObject *gen, PyObject *arg, PyObject **result)
{
    return gen_send_ex2(gen, arg, result, 0, 0);
}
```

看到这里就很令人熟悉了，没错，`gen_send_ex2(coro, None, result, 0, 0)`就是`coro.send(None)`的逻辑

在`gen_send_ex2`中，函数体的返回值会正好赋到`result`上。再看`YIELD_FROM`里`if (gen_status == PYGEN_RETURN)`分支，最终的返回值就会放到栈顶。

当我们调用`xx = await Awaitable`时，我们也就能够把`Awaitable`的返回值赋给`xx`了。这样，`await`原语就实现了它的作用。
