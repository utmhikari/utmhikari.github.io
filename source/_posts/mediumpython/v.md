---
title: 【Medium Python】最终话：如何彻底理解with关键字的用法？
date: 2021/11/13 17:18:06
categories:
- Medium Python
tags:
- python
- 源码分析
- with
- 字节码
- 异常处理
---

Medium Python终于来到了最终话。经历了前四话的撰写，笔者决定以第五话作为收尾，故这段时间一直在思考python里还有什么内容是我们常见但值得推敲且有应用意义的点。绞尽脑汁，最终得到了今天这个主题：`with`关键字。

`with`关键字的含义，是笔者接触python以来希望彻底搞懂的问题之一，也是一定会困惑大量玩python的同学的问题之一。相信每一个玩过python的同学都接触过`with`语法，比如`with open(xxx) as f`的文件操作，或者是`with lock`这样的加解锁操作，这些东西每个python教程里都有。但是`with`语法具体表示什么，具体能够翻译成怎样的简单语法，基本没啥人能够说的清楚，说的科学。即便在网上有许多文章在剖析这一点，提到了许多诸如“上下文管理（`context manager`）”、“异常处理”、“`__enter__`、`__exit__`”之类的词汇，但是就正因为缺少些硬核的东西，比如源码分析，导致许多个文章的内容都很水，看了也不能完完全全的明白，实际写代码的时候也觉得难以彻底掌握。

因此，为了把这件事情说明白，本文决定继续源码分析的套路，让大伙儿彻底理解`with`关键字是怎么一回事。老样子，一切的吹水都没有源码分析来的实在。看完这篇文章，其它关于`with`的文章都可以统统无视了。

## with代码测试

首先我们上一段测试代码：

<!-- more -->

```python
import sys
import dis
import threading
from threading import Lock, Thread
import time


def _seg(msg):
    print('\n'.join(['=' * 40, str(msg), '=' * 40]))


def test_fopen():
    filename = '1.log'
    with open(filename) as f:
        print(f.read())
        f.close()
        pass


_NUM_THREADS = 3
_LOCK = Lock()
_CNT = 0
_MAX_CNT = 100


def _test_thread_lock_task():
    thread_name = threading.current_thread().name
    global _CNT
    while True:
        with _LOCK:
            if _CNT < _MAX_CNT:
                _CNT += 1
                print('[%s] count: %d' % (thread_name, _CNT))
            else:
                print('[%s] count reached max: %d' % (thread_name, _MAX_CNT))
                break
            pass


def test_thread_lock():
    sys.setswitchinterval(0.001)
    threads = []
    for i in range(_NUM_THREADS):
        threads.append(Thread(target=_test_thread_lock_task, name='Thread-%d' % (i + 1)))
    for i in range(_NUM_THREADS):
        threads[i].start()
    time.sleep(0)
    for i in range(_NUM_THREADS):
        threads[i].join()


if __name__ == '__main__':
    test_thread_lock()
    test_fopen()
    _seg('disassemble test_fopen')
    dis.dis(test_fopen)
    _seg('disassemble _test_thread_lock_task')
    dis.dis(_test_thread_lock_task)

```

这段测试代码包含了两个我们常见的`with`操作：文件读写和线程加锁。`test_fopen`是读文件内容，`test_thread_lock`是不同线程交替增加`_CNT`的操作。在代码里面，再次出现了我们的老同志：反编译库`dis`，这是为了用来解析每一个函数具体包含哪些操作码，以能够让我们快速定位对应操作的源代码实现。每个被`dis`的函数，在`with`的最后都有`pass`操作，这是为了更加方便看到在退出`with`范围时，代码实际做了哪些附加操作（嗯，这些`pass`是实际调试之后才加的）。

以文件读写`test_fopen`为例，我们看下反编译之后的结果：

```text
 13           0 LOAD_CONST               1 ('1.log')
              2 STORE_FAST               0 (filename)

 14           4 LOAD_GLOBAL              0 (open)
              6 LOAD_FAST                0 (filename)
              8 CALL_FUNCTION            1
             10 SETUP_WITH              36 (to 48)
             12 STORE_FAST               1 (f)

 15          14 LOAD_GLOBAL              1 (print)
             16 LOAD_FAST                1 (f)
             18 LOAD_METHOD              2 (read)
             20 CALL_METHOD              0
             22 CALL_FUNCTION            1
             24 POP_TOP

 16          26 LOAD_FAST                1 (f)
             28 LOAD_METHOD              3 (close)
             30 CALL_METHOD              0
             32 POP_TOP

 18          34 POP_BLOCK
             36 LOAD_CONST               0 (None)
             38 DUP_TOP
             40 DUP_TOP
             42 CALL_FUNCTION            3
             44 POP_TOP
             46 JUMP_FORWARD            16 (to 64)
        >>   48 WITH_EXCEPT_START
             50 POP_JUMP_IF_TRUE        54
             52 RERAISE
        >>   54 POP_TOP
             56 POP_TOP
             58 POP_TOP
             60 POP_EXCEPT
             62 POP_TOP
        >>   64 LOAD_CONST               0 (None)
             66 RETURN_VALUE
```

我们看到，在`with`的一行（14），多了`SETUP_WITH`的操作指令，而在即将退出`with`代码块的`pass`一行（18），出现了大量指令，并且有点类似于异常处理的内容。那么这里到底蕴含了什么信息呢？
那么首先，我们从`SETUP_WITH`——`with`代码块的初始化操作开始看起。

## with代码块的初始化

我们在`EvalFrame`的循环中，先找到`SETUP_WITH`对应的代码：

```c
// ceval.c

case TARGET(SETUP_WITH): {
    _Py_IDENTIFIER(__enter__);
    _Py_IDENTIFIER(__exit__);
    PyObject *mgr = TOP();
    PyObject *enter = special_lookup(tstate, mgr, &PyId___enter__);
    PyObject *res;
    if (enter == NULL) {
        goto error;
    }
    PyObject *exit = special_lookup(tstate, mgr, &PyId___exit__);
    if (exit == NULL) {
        Py_DECREF(enter);
        goto error;
    }
    SET_TOP(exit);
    Py_DECREF(mgr);
    res = _PyObject_CallNoArg(enter);
    Py_DECREF(enter);
    if (res == NULL)
        goto error;
    /* Setup the finally block before pushing the result
               of __enter__ on the stack. */
    PyFrame_BlockSetup(f, SETUP_FINALLY, INSTR_OFFSET() + oparg,
                       STACK_LEVEL());

    PUSH(res);
    DISPATCH();
}
```

可以看到，`SETUP_WITH`操作的步骤如下：

- 一开始，寻找`with`对应实例的`__enter__`以及`__exit__`方法（绑定实例的），如果两者有其一找不到的话都会直接跳到`error`报错。
- 设置`__exit__`为栈顶
- 直接调用`instance.__enter__()`
- 进行BlockSetup：`PyFrame_BlockSetup(f, SETUP_FINALLY, INSTR_OFFSET() + oparg, STACK_LEVEL())`
- 将`__enter__`的返回值`PUSH`到栈上

在`test_fopen`里面，`__enter__`函数对应的是`iobase_enter`：

```c
// iobase.c

static PyObject *
iobase_enter(PyObject *self, PyObject *args)
{
    if (iobase_check_closed(self))
        return NULL;

    Py_INCREF(self);
    return self;
}
```

可以看到，在`__enter__`函数中会检测这个`io`对象是否已经`close`掉，如果`close`掉的话会返回`NULL`，正常的话返回`io`对象。如果`__enter__`返回`NULL`，在`SETUP_WITH`里面，就`goto`到`error`逻辑了。

之后我们再看一下`BlockSetup`语句，其中会调用`PyFrame_BlockSetup`函数：

```c
// frameobject.c

void
PyFrame_BlockSetup(PyFrameObject *f, int type, int handler, int level)
{
    PyTryBlock *b;
    if (f->f_iblock >= CO_MAXBLOCKS) {
        Py_FatalError("block stack overflow");
    }
    b = &f->f_blockstack[f->f_iblock++];
    b->b_type = type;
    b->b_level = level;
    b->b_handler = handler;
}
```

`PyFrame_BlockSetup`的本质是设置了一个`PyTryBlock`。如果进一步检索`PyFrame_BlockSetup`的引用的话，会发现`SETUP_FINALLY`这个操作本质就是调用了这个函数。而`SETUP_FINALLY`本身，比如在`try/except/finally`结构里，不论是`except`还是`finally`，都用的这个字节码。

`PyTryBlock`除了在`try/except/finally`结构中有使用之外，在循环`loop`的时候也会用到，其三个属性的意义分别为：

- `b_type`：当前代码块`block`的类型（`SETUP_FINALLY`）
- `b_handler`：处理错误信息的`handler`的指令位置（`INSTR_OFFSET() + oparg`）
- `b_level`：比如出现`exception`的场景下，要对栈做恢复，pop一系列栈上的value时，用来参考的栈高度（`STACK_LEVEL()`）

我们进一步看`PyTryBlock`跟`FrameObject`的定义及注释，也可以证实这些信息：

```c
// frameobject.h

typedef struct {
    int b_type;                 /* what kind of block this is */
    int b_handler;              /* where to jump to find handler */
    int b_level;                /* value stack level to pop to */
} PyTryBlock;

struct _frame {
    PyObject_VAR_HEAD
    struct _frame *f_back;      /* previous frame, or NULL */
    PyCodeObject *f_code;       /* code segment */
    PyObject *f_builtins;       /* builtin symbol table (PyDictObject) */
    PyObject *f_globals;        /* global symbol table (PyDictObject) */
    PyObject *f_locals;         /* local symbol table (any mapping) */
    PyObject **f_valuestack;    /* points after the last local */
    /* Next free slot in f_valuestack.  Frame creation sets to f_valuestack.
       Frame evaluation usually NULLs it, but a frame that yields sets it
       to the current stack top. */
    PyObject **f_stacktop;
    PyObject *f_trace;          /* Trace function */
    char f_trace_lines;         /* Emit per-line trace events? */
    char f_trace_opcodes;       /* Emit per-opcode trace events? */

    /* Borrowed reference to a generator, or NULL */
    PyObject *f_gen;

    int f_lasti;                /* Last instruction if called */
    /* Call PyFrame_GetLineNumber() instead of reading this field
       directly.  As of 2.3 f_lineno is only valid when tracing is
       active (i.e. when f_trace is set).  At other times we use
       PyCode_Addr2Line to calculate the line from the current
       bytecode index. */
    int f_lineno;               /* Current line number */
    int f_iblock;               /* index in f_blockstack */
    char f_executing;           /* whether the frame is still executing */
    PyTryBlock f_blockstack[CO_MAXBLOCKS]; /* for try and loop blocks */
    PyObject *f_localsplus[1];  /* locals+stack, dynamically sized */
};
```

有了`PyTryBlock`存储一系列栈上信息，就可以保证`with`结构下的代码块在结束之后，整个栈上的状态能够恢复到`with`之前的状态。注意这个时候栈顶上是`__exit__`函数，这样如果之后恢复栈，然后push一系列错误信息，我们的`__exit__`函数就能处理对应的错误信息了。

`BlockSetup`之后，就是把`__enter__`的返回值推进栈里，交由后面的`STORE`指令存储到`locals`里面。比如我们在`python`中编写的`with a as b`这种形式，最后我们取到的`b`，就是`__enter__`的返回值了。

## with代码块的退出以及异常处理

执行完`with`一行的代码之后，我们开始执行`with`代码块里面的内容。`with`代码块执行完之后，当退出之时，也会执行一系列行为。
从上面的字节码结果中也可以看到，有非常长的一串，这里也再列出来：

```text
 18          34 POP_BLOCK
             36 LOAD_CONST               0 (None)
             38 DUP_TOP
             40 DUP_TOP
             42 CALL_FUNCTION            3
             44 POP_TOP
             46 JUMP_FORWARD            16 (to 64)
        >>   48 WITH_EXCEPT_START
             50 POP_JUMP_IF_TRUE        54
             52 RERAISE
        >>   54 POP_TOP
             56 POP_TOP
             58 POP_TOP
             60 POP_EXCEPT
             62 POP_TOP
        >>   64 LOAD_CONST               0 (None)
             66 RETURN_VALUE
```

退出`with`的一刻，需要考虑两种情况：有异常和没有异常。当没有异常的时候下来，会到字节码的34~46。34先`POP_BLOCK`退出代码块，然后之后有一个`CALL_FUNCTION`操作：由于先前讲到栈顶已经被设置成了`__exit__`函数，那么这里相当于再顶了3个`None`，然后执行了`instance.__exit__(None, None, None)`。之后就走到64，退出这个`with`流程了。
​

而当有异常时，我们会跳到48：`WITH_EXCEPT_START`，这一块在前面`SETUP_WITH`的字节码有标注：

```text
10 SETUP_WITH              36 (to 48)
```

如果说`with`结构最终走到了`WITH_EXCEPT_START`的分支，那么在此之前一定已经执行了某些抛异常（比如`raise`）且没有捕获的操作。为了模拟这个场景，我们在`with`代码块中加一行代码`raise Exception`，来看下抛异常时候的情况。

```python
import dis


def test_with_except():
    with open('./1.log') as f:
        print(f.read())
        raise KeyError('haha')
        pass


if __name__ == '__main__':
    dis.dis(test_with_except)
    test_with_except()

```

用`dis`得到的反编译结果：

```text
  5           0 LOAD_GLOBAL              0 (open)
              2 LOAD_CONST               1 ('./1.log')
              4 CALL_FUNCTION            1
              6 SETUP_WITH              36 (to 44)
              8 STORE_FAST               0 (f)

  6          10 LOAD_GLOBAL              1 (print)
             12 LOAD_FAST                0 (f)
             14 LOAD_METHOD              2 (read)
             16 CALL_METHOD              0
             18 CALL_FUNCTION            1
             20 POP_TOP

  7          22 LOAD_GLOBAL              3 (KeyError)
             24 LOAD_CONST               2 ('haha')
             26 CALL_FUNCTION            1
             28 RAISE_VARARGS            1

  8          30 POP_BLOCK
             32 LOAD_CONST               0 (None)
             34 DUP_TOP
             36 DUP_TOP
             38 CALL_FUNCTION            3
             40 POP_TOP
             42 JUMP_FORWARD            16 (to 60)
        >>   44 WITH_EXCEPT_START
             46 POP_JUMP_IF_TRUE        50
             48 RERAISE
        >>   50 POP_TOP
             52 POP_TOP
             54 POP_TOP
             56 POP_EXCEPT
             58 POP_TOP
        >>   60 LOAD_CONST               0 (None)
             62 RETURN_VALUE
```

我们可以从中看到，当`raise`异常时，会执行`RAISE_VARARGS 1`的指令。我们先来看`RAISE_VARARGS`对应的代码：

```c
// ceval.c

case TARGET(RAISE_VARARGS): {
    PyObject *cause = NULL, *exc = NULL;
    switch (oparg) {
        case 2:
            cause = POP(); /* cause */
            /* fall through */
        case 1:
            exc = POP(); /* exc */
            /* fall through */
        case 0:
            if (do_raise(tstate, exc, cause)) {
                goto exception_unwind;
            }
            break;
        default:
            _PyErr_SetString(tstate, PyExc_SystemError,
                             "bad RAISE_VARARGS oparg");
            break;
    }
    goto error;
}
```

在`RAISE_VARARGS`中，`case`对应的指令会顺着往下走，直到`case 0`的`do_raise`逻辑里面。`do_raise`是抛异常的实际操作，里面会检查抛出的异常类型以及参数是否合理，之后再设置当前线程的异常类型`type`以及异常值`value`
`RAISE_VARARGS`最后会跳到`error`以及`exception_unwind`代码段：

```c
// ceval.c

error:
        /* Double-check exception status. */
#ifdef NDEBUG
        if (!_PyErr_Occurred(tstate)) {
            _PyErr_SetString(tstate, PyExc_SystemError,
                             "error return without exception set");
        }
#else
        assert(_PyErr_Occurred(tstate));
#endif

        /* Log traceback info. */
        PyTraceBack_Here(f);

        if (tstate->c_tracefunc != NULL)
            call_exc_trace(tstate->c_tracefunc, tstate->c_traceobj,
                           tstate, f);

exception_unwind:

// 暂时忽略下面
```

在`error`段中，会提取当前`frame`上的异常`traceback`信息，然后就直接到了`exception_unwind`段。`exception_unwind`段会恢复栈上的信息，其逻辑如下：

```c
// ceval.c

exception_unwind:
        /* Unwind stacks if an exception occurred */
  while (f->f_iblock > 0) {
            /* Pop the current block. */
            PyTryBlock *b = &f->f_blockstack[--f->f_iblock];

            if (b->b_type == EXCEPT_HANDLER) {
                UNWIND_EXCEPT_HANDLER(b);
                continue;
            }
            UNWIND_BLOCK(b);
            if (b->b_type == SETUP_FINALLY) {
                PyObject *exc, *val, *tb;
                int handler = b->b_handler;
                _PyErr_StackItem *exc_info = tstate->exc_info;
                /* Beware, this invalidates all b->b_* fields */
                PyFrame_BlockSetup(f, EXCEPT_HANDLER, -1, STACK_LEVEL());
                PUSH(exc_info->exc_traceback);
                PUSH(exc_info->exc_value);
                if (exc_info->exc_type != NULL) {
                    PUSH(exc_info->exc_type);
                }
                else {
                    Py_INCREF(Py_None);
                    PUSH(Py_None);
                }
                _PyErr_Fetch(tstate, &exc, &val, &tb);
                /* Make the raw exception data
                   available to the handler,
                   so a program can emulate the
                   Python main loop. */
                _PyErr_NormalizeException(tstate, &exc, &val, &tb);
                if (tb != NULL)
                    PyException_SetTraceback(val, tb);
                else
                    PyException_SetTraceback(val, Py_None);
                Py_INCREF(exc);
                exc_info->exc_type = exc;
                Py_INCREF(val);
                exc_info->exc_value = val;
                exc_info->exc_traceback = tb;
                if (tb == NULL)
                    tb = Py_None;
                Py_INCREF(tb);
                PUSH(tb);
                PUSH(val);
                PUSH(exc);
                JUMPTO(handler);
                if (_Py_TracingPossible(ceval2)) {
                    int needs_new_execution_window = (f->f_lasti < instr_lb || f->f_lasti >= instr_ub);
                    int needs_line_update = (f->f_lasti == instr_lb || f->f_lasti < instr_prev);
                    /* Make sure that we trace line after exception if we are in a new execution
                     * window or we don't need a line update and we are not in the first instruction
                     * of the line. */
                    if (needs_new_execution_window || (!needs_line_update && instr_lb > 0)) {
                        instr_prev = INT_MAX;
                    }
                }
                /* Resume normal execution */
                goto main_loop;
            }
        } /* unwind stack */
```

由于我们先前执行过了`PyFrame_BlockSetup(f, SETUP_FINALLY, INSTR_OFFSET() + oparg, STACK_LEVEL())`，最终代码会运行到`if (b->b_type == SETUP_FINALLY)`对应的段落。在其中进行了以下步骤：

- `PyFrame_BlockSetup(f, EXCEPT_HANDLER, -1, STACK_LEVEL())`：设定了一个新的代码块，标识为`EXCEPT_HANDLER`
- 将异常栈（串连异常信息的链）当前最顶端的异常信息push到栈中
- 将当前需要`raise`的异常信息push到栈中
  - 这个场景下，应当和异常栈最顶端的一样
  - 注意`_PyErr_Fetch`会将表示当前线程要抛出的异常的几个变量（`curexc_type`、`curexc_value`、`curexc_traceback`）重置为`NULL`。这样如果当前异常得到妥善处理掉，后面执行时候发现线程里面这些变量是`NULL`，也不会触发程序终止打印异常。
  - `_PyErr_Fetch`相反的操作叫做`_PyErr_Restore`，相当于设定当前线程已经出现异常。

进行了这个操作之后，现在栈上应当至少有7个元素，自顶而下是：

- 前3个是当前需要`raise`的异常信息
- 中间3个是异常栈最顶端的异常信息
- 然后第7个就是`__exit__`函数

之后通过`JUMPTO(handler)`、`goto main_loop`，就走到了`WITH_EXCEPT_START`逻辑

```c
// ceval.c

case TARGET(WITH_EXCEPT_START): {
    /* At the top of the stack are 7 values:
       - (TOP, SECOND, THIRD) = exc_info()
       - (FOURTH, FIFTH, SIXTH) = previous exception for EXCEPT_HANDLER
       - SEVENTH: the context.__exit__ bound method
       We call SEVENTH(TOP, SECOND, THIRD).
       Then we push again the TOP exception and the __exit__ return value.
    */
    PyObject *exit_func;
    PyObject *exc, *val, *tb, *res;

    exc = TOP();
    val = SECOND();
    tb = THIRD();
    assert(exc != Py_None);
    assert(!PyLong_Check(exc));
    exit_func = PEEK(7);
    PyObject *stack[4] = {NULL, exc, val, tb};
    res = PyObject_Vectorcall(exit_func, stack + 1,
                              3 | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL);
    if (res == NULL)
        goto error;

    PUSH(res);
    DISPATCH();
}
```

在`WITH_EXCEPT_START`的逻辑里，直接调用了`instance.__exit__(exc_type, exc_value, exc_traceback)`，然后把结果再推到栈上。这样栈上就有8个元素了。
以先前的`with open(xxx) as f`为例，其`__exit__`函数对应了`iobase_exit`

```c
// iobase.c

static PyObject *
iobase_exit(PyObject *self, PyObject *args)
{
    return PyObject_CallMethodNoArgs(self, _PyIO_str_close);
}
```

可以看到这个函数会返回`f.close`的返回值，其实就是`None`，并且对异常信息（包在`args`里）没有任何处理。
`__exit__`函数的返回值有什么用处呢？我们看到紧接着的操作是`POP_JUMP_IF_TRUE`：

```c
// ceval.c

case TARGET(POP_JUMP_IF_TRUE): {
    PREDICTED(POP_JUMP_IF_TRUE);
    PyObject *cond = POP();
    int err;
    if (cond == Py_False) {
        Py_DECREF(cond);
        FAST_DISPATCH();
    }
    if (cond == Py_True) {
        Py_DECREF(cond);
        JUMPTO(oparg);
        FAST_DISPATCH();
    }
    err = PyObject_IsTrue(cond);
    Py_DECREF(cond);
    if (err > 0) {
        JUMPTO(oparg);
    }
    else if (err == 0)
        ;
    else
        goto error;
    DISPATCH();
}
```

可以看到，一开始我们会`POP`出来栈顶的值，也就是`__exit__`的返回值，然后再根据这个返回值走下面的逻辑。如果这个返回值可以作为真值（比如1、有内容的`list`/`dict`）的话，就跳到指定的指令，如果不是真值（比如`None`、0、空的`list`/`dict`）的话，就接续下去。因此结合先前反编译操作码的结果来看，会是这样的效果：

- 如果`__exit__`返回真值，则走后面的`POP`一堆东西的逻辑（50）
  - 理论上，不会结束程序，打不打印异常看你在`__exit__`里有没有操作了
- 如果`__exit__`返回非真值，就走下面的`RERAISE`指令（48），结束程序打印异常

首先来看`RERAISE`：

```c
case TARGET(RERAISE): {
    PyObject *exc = POP();
    PyObject *val = POP();
    PyObject *tb = POP();
    assert(PyExceptionClass_Check(exc));
    _PyErr_Restore(tstate, exc, val, tb);
    goto exception_unwind;
}
```

`RERAISE`实际把栈顶3个待`raise`的异常信息POP出来，并通过`_PyErr_Restore`重新设置当前线程出现的异常信息，然后又走到了`exception_unwind`。在`exception_unwind`的遍历代码块的`while`循环中，首先识别到先前`BlockSetup`的`EXCEPT_HANDLER`代码段，调用`UNWIND_EXCEPT_HANDLER`把先前`PUSH`的异常栈顶的异常信息全给`POP`了，之后由于没有任何`SETUP_FINALLY`的标记，整个遍历代码块就结束了，最终就会把栈里剩下的值（`__exit__`）清掉，退出代码执行。
代码执行完毕之后，由于表示当前线程要抛出的异常的几个变量被`_PyErr_Restore`设置了，最终就会触发程序终止，并在`stderr`打印异常信息。

然后我们再看`__exit__`返回真值情况下那一堆`POP`操作，大概是这样：

- 首先是3个`POP_TOP`，把待`raise`的异常信息`POP`掉
- 然后是`POP_EXCEPT`，一方面会退出前面设置的`EXCEPT_HANDLER`代码段，另一方面会把先前`PUSH`进去的那个时刻的异常栈顶的信息给POP出来，并重新设置到异常栈顶上，保证异常信息恢复原样
- 最后又来一个`POP_TOP`，就是把`__exit__`给POP掉

这样，整个`with`代码块的部分就执行完成了！

## 总结

`with`关键字分析了那么久，大家也能够看的明白，`with`本身其实相当于`try/except/finally`结构的变体。剖析`with`结构的同时，也不得不需要参考异常处理相关的代码逻辑。这篇文章与其说在讲`with`，不如说在讲一些异常处理相关的实现。
​
从上面的分析结果，我们就可以得出来：
​
比如一个python代码段：

```python
with a as b:
    xxx
    yyy
    zzz
```

就能够被简单地翻译为：

```python
b = a.__enter__()
try:
    xxx
    yyy
    zzz
except exception_type, exception_value, exception_traceback:
    # handle exception
    ok = a.__exit__(exception_type, exception_value, exception_traceback)
    if not ok:
        # RERAISE
        raise (exception_type, exception_value, exception_traceback)
else:
    # normal ending
    a.__exit__(None, None, None)
```

翻译成这样，每一个学过一点python的同学都会很清楚地理解吧！

那么，如果我们要自己编写支持with语法的程序，可以参考下面的python代码：

```python
import pprint


class WithTester(object):
    def __init__(self):
        self.__flag = 0

    def __enter__(self):
        self.__flag = 1
        print('[WithTester] triggered enter: %d' % self.__flag)
        return self.__flag + 99

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.__flag = 0
        print('[WithTester] triggered exit: %d\n%s' % (
            self.__flag,
            pprint.pformat({
                'exc_type': exc_type,
                'exc_val': exc_val,
                'exc_tb': exc_tb
            })
        ))
        return 'a true value'


def main():
    wt = WithTester()
    with wt as f:
        print(type(f))
        print(f)
        print('haha')
        raise KeyError('hehe')
```

支持`with`的实例，需要有只带`self`一个参数的`__enter__`函数，以及带`self`以及异常类型、异常值、异常traceback三个参数的`__exit__`函数。通过上面“代码翻译”的样式，不难看出，执行`main`函数会输出这样的结果，不带`Exception`报错：

```text
[WithTester] triggered enter: 1
<class 'int'>
100
haha
[WithTester] triggered exit: 0
{'exc_tb': <traceback object at 0x000001D64D6F58C0>,
 'exc_type': <class 'KeyError'>,
 'exc_val': KeyError('hehe')}
```

看到了吧！`with`关键字的含义，就是这样简单。
​

## 写在最后的话

相信通过Medium Python系列的讲解，大家应该会对python语言本身有了新的理解吧！在最后，笔者也推荐一本书：《Python源码剖析》，是一本老书，基于python2.5的，但是在python已经到3.10的今天，读起来仍然令人大开眼界。这个系列的许多分析，都参考了这本书的分析方法以及结论。

​
知识是永远没有尽头的！做这个系列的过程中，笔者是一次又一次地在体验着这样的真理。今后的将来，希望大家一起勉励！
​
