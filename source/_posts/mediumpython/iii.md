---
title: 【Medium Python】第三话：python多线程为什么不能并行？
date: 2021/10/30 19:44:40
categories:
- Medium Python
tags:
- python
- 多线程
- GIL
- opcode
- 源码分析
---

python的多线程，这是个老生常谈的话题了，网上资料也一大把。python默认的`threading`模块对多线程提供了支持，但实际多个`threading.Thread`实例无法并行运行（不是无法并发哦！）。
​
一句话概括答案：**python的线程实质是操作系统原生的线程，而每个线程要执行python代码的话，需要获得对应代码解释器的锁GIL。一般我们运行python程序都只有一个解释器，这样不同线程需要获得同一个锁才能执行各自的代码，互斥了，于是代码就不能同时运行了。**
​
好的，接下来我们细细讲解这句话背后的故事：

## 多线程并行测试

首先我们通过一些代码来测试多线程是否真的并行：

<!-- more -->

```python
import threading
import datetime
import time


COUNT = int(1e8)


def _count_task(start, end):
    start_time = datetime.datetime.now()
    while start < end:
        start += 1
    duration = datetime.datetime.now() - start_time
    cur_thread_name = threading.current_thread().name
    print('[THREAD] [%s] %.4f seconds' % (cur_thread_name, duration.total_seconds()))


def increment_singlethread():
    print('[SINGLE_THREAD] start by count pair: (%d, %d)' % (0, COUNT))
    start_time = datetime.datetime.now()
    _count_task(0, COUNT)
    duration = datetime.datetime.now() - start_time
    print('[SINGLE_THREAD] %.4f seconds' % duration.total_seconds())


NUM_THREADS = 5


def _get_counts():
    segs = [0]
    div, mod = int(COUNT / NUM_THREADS), int(COUNT % NUM_THREADS)
    for i in range(NUM_THREADS):
        segs.append(div)
    for i in range(mod):
        segs[i + 1] += 1
    for i in range(1, len(segs)):
        segs[i] += segs[i - 1]
    cnts = []
    segs[0] = -1
    for i in range(NUM_THREADS):
        cnts.append((segs[i] + 1, segs[i + 1]))
    return cnts


def increment_multithread():
    cnts = _get_counts()
    print('[MULTI_THREAD] start by counts: %s' % cnts)
    threads = []
    for i in range(NUM_THREADS):
        threads.append(threading.Thread(
            target=_count_task,
            args=cnts[i],
            name='Task-%d' % i
        ))
    start_time = datetime.datetime.now()
    for i in range(NUM_THREADS):
        threads[i].start()
    time.sleep(0)  # yield exexcution to task threads
    for i in range(NUM_THREADS):
        threads[i].join()
    duration = datetime.datetime.now() - start_time
    print('[MULTI_THREAD] %.4f seconds' % duration.total_seconds())


if __name__ == '__main__':
    increment_singlethread()
    increment_multithread()

```

这是个测试代码，总共执行COUNT次+=1的操作，一个是单线程，一个是多线程。出来的结果，两种方式没有明显的时间上的差异：

```text
[SINGLE_THREAD] start by count pair: (0, 100000000)
[THREAD] [MainThread] 7.1221 seconds
[SINGLE_THREAD] 7.1221 seconds
[MULTI_THREAD] start by counts: [(0, 20000000), (20000001, 40000000), (40000001, 60000000), (60000001, 80000000), (80000001, 100000000)]
[THREAD] [Task-3] 5.8285 seconds
[THREAD] [Task-0] 6.0101 seconds
[THREAD] [Task-4] 6.6114 seconds
[THREAD] [Task-1] 6.9136 seconds
[THREAD] [Task-2] 6.9735 seconds
[MULTI_THREAD] 7.0034 seconds
```

这也侧面证明了基于`threading.Thread`的多线程并非完全并行运行的。为了深入确认这个问题，我们需要看下python内部的线程运行的机制

## 线程是如何启动的

我们首先看下线程启动的过程，直接从`Thread`类的`start`方法开始：

```python
class Thread:
    """A class that represents a thread of control.

    This class can be safely subclassed in a limited fashion. There are two ways
    to specify the activity: by passing a callable object to the constructor, or
    by overriding the run() method in a subclass.

    """
    def start(self):
        """Start the thread's activity.

        It must be called at most once per thread object. It arranges for the
        object's run() method to be invoked in a separate thread of control.

        This method will raise a RuntimeError if called more than once on the
        same thread object.

        """
        if not self._initialized:
            raise RuntimeError("thread.__init__() not called")

        if self._started.is_set():
            raise RuntimeError("threads can only be started once")
        with _active_limbo_lock:
            _limbo[self] = self
        try:
            _start_new_thread(self._bootstrap, ())
        except Exception:
            with _active_limbo_lock:
                del _limbo[self]
            raise
        self._started.wait()
```

`start`方法中，从行为上来看是这么一个逻辑：

- 首先会检查`Thread`实例是否已经初始化，是否没有启动过
- 然后会把自己加入到`_limbo`中
- 调用启动线程的方法`_start_new_thread`，把自己的`_bootstrap`方法也带进去
  - `_bootstrap`是python端最终开始线程任务所调用的逻辑，是在新线程里运行的！后面会慢慢看到
- 等待`self._started`（一个Event实例）的信号

首先来看`_limbo`的作用。玩游戏玩多的同学都知道，`limbo`叫做“地狱边境”，如果再查下字典的话，我们可以将之简单理解为“准备态”。先记录线程为“准备态”，然后才会开始真正执行线程启动的过程。线程启动的过程是在C层进行的，我们点进`_start_new_thread`的定义就能看到python层是没有对应的代码的。

```c
// _threadmodule.c

static PyObject *
thread_PyThread_start_new_thread(PyObject *self, PyObject *fargs)
{
    _PyRuntimeState *runtime = &_PyRuntime;
    PyObject *func, *args, *keyw = NULL;
    struct bootstate *boot;
    unsigned long ident;
 
    // 解包function跟args并检查合法性
    if (!PyArg_UnpackTuple(fargs, "start_new_thread", 2, 3,
                           &func, &args, &keyw))
        return NULL;
    if (!PyCallable_Check(func)) {
        PyErr_SetString(PyExc_TypeError,
                        "first arg must be callable");
        return NULL;
    }
    if (!PyTuple_Check(args)) {
        PyErr_SetString(PyExc_TypeError,
                        "2nd arg must be a tuple");
        return NULL;
    }
    if (keyw != NULL && !PyDict_Check(keyw)) {
        PyErr_SetString(PyExc_TypeError,
                        "optional 3rd arg must be a dictionary");
        return NULL;
    }

    PyInterpreterState *interp = _PyInterpreterState_GET();
    if (interp->config._isolated_interpreter) {
        PyErr_SetString(PyExc_RuntimeError,
                        "thread is not supported for isolated subinterpreters");
        return NULL;
    }
 
    // 设置bootstate实例
    boot = PyMem_NEW(struct bootstate, 1);
    if (boot == NULL)
        return PyErr_NoMemory();
    boot->interp = _PyInterpreterState_GET();
    boot->func = func;
    boot->args = args;
    boot->keyw = keyw;
    boot->tstate = _PyThreadState_Prealloc(boot->interp);
    boot->runtime = runtime;
    if (boot->tstate == NULL) {
        PyMem_DEL(boot);
        return PyErr_NoMemory();
    }
    Py_INCREF(func);
    Py_INCREF(args);
    Py_XINCREF(keyw);
 
    // 启动线程，传参t_bootstrap跟bootstate实例
    ident = PyThread_start_new_thread(t_bootstrap, (void*) boot);
    if (ident == PYTHREAD_INVALID_THREAD_ID) {
        PyErr_SetString(ThreadError, "can't start new thread");
        Py_DECREF(func);
        Py_DECREF(args);
        Py_XDECREF(keyw);
        PyThreadState_Clear(boot->tstate);
        PyMem_DEL(boot);
        return NULL;
    }
    return PyLong_FromUnsignedLong(ident);
}
```

python中的`_start_new_thread`，对应了C层的`thread_PyThread_start_new_thread`，而`thread_PyThread_start_new_thread`传入的两个参数`self`跟`fargs`，则对应python代码里的`self._bootstrap`跟空的tuple。`_start_new_thread`的大致步骤如下：

- 解包`fargs`，并检查合法性。这里由于进了空的tuple，所以暂时不需要过多分析。
- 设置`bootstate`实例`boot`
  - 一个`bootstate`是`fargs`以及对应的`thread state`、`intepreter state`以及`runtime state`的打包，囊括了启动新线程需要有的信息
- 调用`PyThread_start_new_thread`函数，把`bootstate`实例以及一个回调函数`t_bootstrap`传进去
  - 其返回值是线程的实例ID，在python端，我们也可以通过线程实例的`ident`属性得到。
  - `t_bootstrap`回调函数，是需要在新启动的子线程里运行的！

`PyThread_start_new_thread`函数，根据不同操作系统环境有不同的定义。以windows环境为例，其定义如下：

```c
// thread_nt.h

/* thunker to call adapt between the function type used by the system's
thread start function and the internally used one. */
static unsigned __stdcall
bootstrap(void *call)
{
    callobj *obj = (callobj*)call;
    void (*func)(void*) = obj->func;
    void *arg = obj->arg;
    HeapFree(GetProcessHeap(), 0, obj);
    func(arg);
    return 0;
}

unsigned long
PyThread_start_new_thread(void (*func)(void *), void *arg)
{
    HANDLE hThread;
    unsigned threadID;
    callobj *obj;

    dprintf(("%lu: PyThread_start_new_thread called\n",
             PyThread_get_thread_ident()));
    if (!initialized)
        PyThread_init_thread();

    obj = (callobj*)HeapAlloc(GetProcessHeap(), 0, sizeof(*obj));
    if (!obj)
        return PYTHREAD_INVALID_THREAD_ID;
    obj->func = func;
    obj->arg = arg;
    PyThreadState *tstate = _PyThreadState_GET();
    size_t stacksize = tstate ? tstate->interp->pythread_stacksize : 0;
    hThread = (HANDLE)_beginthreadex(0,
                      Py_SAFE_DOWNCAST(stacksize, Py_ssize_t, unsigned int),
                      bootstrap, obj,
                      0, &threadID);
    if (hThread == 0) {
        /* I've seen errno == EAGAIN here, which means "there are
         * too many threads".
         */
        int e = errno;
        dprintf(("%lu: PyThread_start_new_thread failed, errno %d\n",
                 PyThread_get_thread_ident(), e));
        threadID = (unsigned)-1;
        HeapFree(GetProcessHeap(), 0, obj);
    }
    else {
        dprintf(("%lu: PyThread_start_new_thread succeeded: %p\n",
                 PyThread_get_thread_ident(), (void*)hThread));
        CloseHandle(hThread);
    }
    return threadID;
}
```

参数`func`和`arg`，对应的是`t_bootstrap`回调跟`bootstate`实例。为了适配`windows`下的`_beginthreadex`接口定义，`t_bootstrap`跟`bootstate`实例又打包成`callobj`，作为`bootstrap`函数（适配用）的参数，随`bootstrap`一起入参`_beginthreadex`。

**这时候我们已经可以确定，python启动的新线程是操作系统的原生线程。**

新线程诞生时，调用了`bootstrap`，在`bootstrap`里拆包`callobj`，调用`func(arg)`，也就是`t_bootstrap(boot)`

```c
// _threadmodule.c

static void
t_bootstrap(void *boot_raw)
{
    struct bootstate *boot = (struct bootstate *) boot_raw;
    PyThreadState *tstate;
    PyObject *res;

    tstate = boot->tstate;
    tstate->thread_id = PyThread_get_thread_ident();  // reset thread ID
    _PyThreadState_Init(tstate);
    PyEval_AcquireThread(tstate);  // take gil for executing thread task
    tstate->interp->num_threads++;
    res = PyObject_Call(boot->func, boot->args, boot->keyw);
    if (res == NULL) {
        if (PyErr_ExceptionMatches(PyExc_SystemExit))
            /* SystemExit is ignored silently */
            PyErr_Clear();
        else {
            _PyErr_WriteUnraisableMsg("in thread started by", boot->func);
        }
    }
    else {
        Py_DECREF(res);
    }
    Py_DECREF(boot->func);
    Py_DECREF(boot->args);
    Py_XDECREF(boot->keyw);
    PyMem_DEL(boot_raw);
    tstate->interp->num_threads--;
    PyThreadState_Clear(tstate);
    _PyThreadState_DeleteCurrent(tstate);

    // bpo-44434: Don't call explicitly PyThread_exit_thread(). On Linux with
    // the glibc, pthread_exit() can abort the whole process if dlopen() fails
    // to open the libgcc_s.so library (ex: EMFILE error).
}
```

回到`t_bootstrap`中，我们发现，最终`t_bootstrap`会取出来`boot`的`func`&`args`，然后调用`PyObject_Call`调用`func(args)`。回到前面去看，这个`func(args)`就是python端的`self._bootstrap()`

```python
class Thread:
    def _bootstrap(self):
        # Wrapper around the real bootstrap code that ignores
        # exceptions during interpreter cleanup.  Those typically
        # happen when a daemon thread wakes up at an unfortunate
        # moment, finds the world around it destroyed, and raises some
        # random exception *** while trying to report the exception in
        # _bootstrap_inner() below ***.  Those random exceptions
        # don't help anybody, and they confuse users, so we suppress
        # them.  We suppress them only when it appears that the world
        # indeed has already been destroyed, so that exceptions in
        # _bootstrap_inner() during normal business hours are properly
        # reported.  Also, we only suppress them for daemonic threads;
        # if a non-daemonic encounters this, something else is wrong.
        try:
            self._bootstrap_inner()
        except:
            if self._daemonic and _sys is None:
                return
            raise
   
 def _bootstrap_inner(self):
        try:
            self._set_ident()
            self._set_tstate_lock()
            if _HAVE_THREAD_NATIVE_ID:
                self._set_native_id()
            self._started.set()
            with _active_limbo_lock:
                _active[self._ident] = self
                del _limbo[self]

            if _trace_hook:
                _sys.settrace(_trace_hook)
            if _profile_hook:
                _sys.setprofile(_profile_hook)

            try:
                self.run()
            except:
                self._invoke_excepthook(self)
        finally:
            with _active_limbo_lock:
                try:
                    # We don't call self._delete() because it also
                    # grabs _active_limbo_lock.
                    del _active[get_ident()]
                except:
                    pass
            
```

在`self._bootstrap_inner()`中，大致有以下步骤：

- notify `self._started`，这样先前python端的`start`函数流程就完成了
- 把自己从准备态`_limbo`中移除，并把自己加到`active`态里
- 执行`self.run`，开始线程逻辑

这样，python中新线程启动的全貌就展现在我们面前了。除了线程的来源外，很多关于线程相关的基础问题（比如为啥不能直接执行`self.run`），答案也都一目了然

## 线程执行代码的过程

在先前一小节我们知晓了python新的线程从何而来，然而，只有通过剖析线程执行代码的过程，我们才可以明确为什么python线程不能并行运行。

一个线程执行其任务，最终还是要落实到`run`方法上来。首先我们通过python自带的反编译库`dis`来看下Thread的run函数对应的操作码（opcode），这样就通过python内部对应opcode的执行逻辑来进一步分析：

```python
class Thread:
    def run(self):
        """Method representing the thread's activity.

        You may override this method in a subclass. The standard run() method
        invokes the callable object passed to the object's constructor as the
        target argument, if any, with sequential and keyword arguments taken
        from the args and kwargs arguments, respectively.

        """
        try:
            if self._target:
                self._target(*self._args, **self._kwargs)
        finally:
            # Avoid a refcycle if the thread is running a function with
            # an argument that has a member that points to the thread.
            del self._target, self._args, self._kwargs
```

其中真正执行函数的一行`self._target(*self._args, **self._kwargs)`，对应的opcodes是：

```text
910           8 LOAD_FAST                0 (self)
             10 LOAD_ATTR                0 (_target)
             12 LOAD_FAST                0 (self)
             14 LOAD_ATTR                1 (_args)
             16 BUILD_MAP                0
             18 LOAD_FAST                0 (self)
             20 LOAD_ATTR                2 (_kwargs)
             22 DICT_MERGE               1
             24 CALL_FUNCTION_EX         1
             26 POP_TOP
        >>   28 POP_BLOCK
```

很明显，`CALL_FUNCTION_EX`——调用函数，就是我们需要找到的opcode。

```c
// ceval.c
PyObject* _Py_HOT_FUNCTION
_PyEval_EvalFrameDefault(PyThreadState *tstate, PyFrameObject *f, int throwflag)
{
    // 省略超多行
    switch (opcode) {
        // 省略超多行
        case TARGET(CALL_FUNCTION_EX): {
            // 检查函数跟参数
            PREDICTED(CALL_FUNCTION_EX);
            PyObject *func, *callargs, *kwargs = NULL, *result;
            if (oparg & 0x01) {
                kwargs = POP();
                if (!PyDict_CheckExact(kwargs)) {
                    PyObject *d = PyDict_New();
                    if (d == NULL)
                        goto error;
                    if (_PyDict_MergeEx(d, kwargs, 2) < 0) {
                        Py_DECREF(d);
                        format_kwargs_error(tstate, SECOND(), kwargs);
                        Py_DECREF(kwargs);
                        goto error;
                    }
                    Py_DECREF(kwargs);
                    kwargs = d;
                }
                assert(PyDict_CheckExact(kwargs));
            }
            callargs = POP();
            func = TOP();
            if (!PyTuple_CheckExact(callargs)) {
                if (check_args_iterable(tstate, func, callargs) < 0) {
                    Py_DECREF(callargs);
                    goto error;
                }
                Py_SETREF(callargs, PySequence_Tuple(callargs));
                if (callargs == NULL) {
                    goto error;
                }
            }
            assert(PyTuple_CheckExact(callargs));
            // 调用函数
            result = do_call_core(tstate, func, callargs, kwargs);
            Py_DECREF(func);
            Py_DECREF(callargs);
            Py_XDECREF(kwargs);

            SET_TOP(result);
            if (result == NULL) {
                goto error;
            }
            DISPATCH();
        }
        // 省略超多行
    }
    // 省略超多行
}
```

在`ceval.c`中，超大函数`_PyEval_EvalFrameDefault`就是用来解析opcode的方法，在这个函数里可以检索opcode研究对应的逻辑。找到`CALL_FUNCTION_EX`对应的逻辑，我们可以分析函数调用的过程，顺藤摸瓜，最终会落实到这里：

```c
// call.c

PyObject *
_PyObject_Call(PyThreadState *tstate, PyObject *callable,
               PyObject *args, PyObject *kwargs)
{
    ternaryfunc call;
    PyObject *result;

    /* PyObject_Call() must not be called with an exception set,
       because it can clear it (directly or indirectly) and so the
       caller loses its exception */
    assert(!_PyErr_Occurred(tstate));
    assert(PyTuple_Check(args));
    assert(kwargs == NULL || PyDict_Check(kwargs));

    if (PyVectorcall_Function(callable) != NULL) {
        return PyVectorcall_Call(callable, args, kwargs);
    }
    else {
        call = Py_TYPE(callable)->tp_call;
        if (call == NULL) {
            _PyErr_Format(tstate, PyExc_TypeError,
                          "'%.200s' object is not callable",
                          Py_TYPE(callable)->tp_name);
            return NULL;
        }

        if (_Py_EnterRecursiveCall(tstate, " while calling a Python object")) {
            return NULL;
        }

        result = (*call)(callable, args, kwargs);

        _Py_LeaveRecursiveCall(tstate);

        return _Py_CheckFunctionResult(tstate, callable, result, NULL);
    }
}
```

在`_PyObject_Call`中，调用函数的方式最后都以通用的形式（`vectorcall`以及`Py_TYPE(callable)->tp_call`）呈现，这说明入参不同的`callable`，可能需要不同的caller方法来handle。基于此，我们可以通过直接debug线程类Thread的`run`方法（在主线程直接跑就行了），来观察线程run函数调用的过程。测试代码如下：

```python
from threading import Thread
def _stat(a, b): print(a + b)
t = Thread(target=_stat, args=(2, 5))
t.run()
```

`t.run`中的`self._target(*self._args, **self._kwargs)`一行触发了`_PyObject_Call`中`PyVectorcall_Call`分支。一路step into下去，最终来到了`_PyEval_EvalFrame`函数：

```c
static inline PyObject*
_PyEval_EvalFrame(PyThreadState *tstate, PyFrameObject *f, int throwflag)
{
    return tstate->interp->eval_frame(tstate, f, throwflag);
}
```

`frame`就是python函数调用栈上面的单位实例（类似于lua的`callinfo`），包含了一个函数调用的相关信息。`eval_frame`就是对`frame`保存的`code`（代码）实例解析并执行。解释器用的是`tstate->interp`，从先前线程启动的逻辑来看，在`thread_PyThread_start_new_thread`里，主线程就把自己的`interp`给到子线程了，所以不管创建多少个线程，所有线程都共用一套解释器。那解释器的`eval_frame`是什么呢？兜兜转转，又回到了超大函数`_PyEval_EvalFrameDefault`。

从`_PyEval_EvalFrameDefault`的`main_loop`这个goto记号往下，就是无限循环处理opcode了。但在switch opcode之前，有一个判断逻辑：

```c
// ceval.c
PyObject* _Py_HOT_FUNCTION
_PyEval_EvalFrameDefault(PyThreadState *tstate, PyFrameObject *f, int throwflag)
{
    // 省略上面
main_loop:
    for (;;) {
        // 省略上面
  if (_Py_atomic_load_relaxed(eval_breaker)) {
            opcode = _Py_OPCODE(*next_instr);
            if (opcode == SETUP_FINALLY ||
                opcode == SETUP_WITH ||
                opcode == BEFORE_ASYNC_WITH ||
                opcode == YIELD_FROM) {
                /* Few cases where we skip running signal handlers and other
                   pending calls:
                   - If we're about to enter the 'with:'. It will prevent
                     emitting a resource warning in the common idiom
                     'with open(path) as file:'.
                   - If we're about to enter the 'async with:'.
                   - If we're about to enter the 'try:' of a try/finally (not
                     *very* useful, but might help in some cases and it's
                     traditional)
                   - If we're resuming a chain of nested 'yield from' or
                     'await' calls, then each frame is parked with YIELD_FROM
                     as its next opcode. If the user hit control-C we want to
                     wait until we've reached the innermost frame before
                     running the signal handler and raising KeyboardInterrupt
                     (see bpo-30039).
                */
                goto fast_next_opcode;
            }

            if (eval_frame_handle_pending(tstate) != 0) {
                goto error;
            }
        }
        // 省略下面
    }
 // 省略下面
}
```

这段代码首先会判断代码解释是否达到中断条件`eval_breaker`，如果达到了的话，可能会走到`eval_frame_handle_pending`处理中断。

```c
// ceval.c

/* Handle signals, pending calls, GIL drop request
   and asynchronous exception */
static int
eval_frame_handle_pending(PyThreadState *tstate)
{
    _PyRuntimeState * const runtime = &_PyRuntime;
    struct _ceval_runtime_state *ceval = &runtime->ceval;

    /* Pending signals */
    if (_Py_atomic_load_relaxed(&ceval->signals_pending)) {
        if (handle_signals(tstate) != 0) {
            return -1;
        }
    }

    /* Pending calls */
    struct _ceval_state *ceval2 = &tstate->interp->ceval;
    if (_Py_atomic_load_relaxed(&ceval2->pending.calls_to_do)) {
        if (make_pending_calls(tstate) != 0) {
            return -1;
        }
    }

    /* GIL drop request */
    if (_Py_atomic_load_relaxed(&ceval2->gil_drop_request)) {
        /* Give another thread a chance */
        if (_PyThreadState_Swap(&runtime->gilstate, NULL) != tstate) {
            Py_FatalError("tstate mix-up");
        }
        drop_gil(ceval, ceval2, tstate);

        /* Other threads may run now */

        take_gil(tstate);

        if (_PyThreadState_Swap(&runtime->gilstate, tstate) != NULL) {
            Py_FatalError("orphan tstate");
        }
    }

    /* Check for asynchronous exception. */
    if (tstate->async_exc != NULL) {
        PyObject *exc = tstate->async_exc;
        tstate->async_exc = NULL;
        UNSIGNAL_ASYNC_EXC(tstate->interp);
        _PyErr_SetNone(tstate, exc);
        Py_DECREF(exc);
        return -1;
    }

#ifdef MS_WINDOWS
    // bpo-42296: On Windows, _PyEval_SignalReceived() can be called in a
    // different thread than the Python thread, in which case
    // _Py_ThreadCanHandleSignals() is wrong. Recompute eval_breaker in the
    // current Python thread with the correct _Py_ThreadCanHandleSignals()
    // value. It prevents to interrupt the eval loop at every instruction if
    // the current Python thread cannot handle signals (if
    // _Py_ThreadCanHandleSignals() is false).
    COMPUTE_EVAL_BREAKER(tstate->interp, ceval, ceval2);
#endif

    return 0;
}
```

`eval_frame_handle_pending`处理了多种opcode解析中断的场景。在这里我们可以看到，不论是哪个线程跑到这里，如果遇到了`gil_drop_request`，就得`drop_gil`给到其他线程，之后再尝试`take_gil`，重新竞争解释器锁。
在先前讲解线程启动逻辑的时候，新线程调用的`t_bootstrap`函数里，有一句`PyEval_AcquireThread(tstate)`，这里面就包含了`take_gil`的逻辑。我们可以看一下`take_gil`到底干了什么事情：

```c
// ceval_gil.h

/* Take the GIL.

   The function saves errno at entry and restores its value at exit.

   tstate must be non-NULL. */
static void
take_gil(PyThreadState *tstate)
{
    // 省略上面

    if (!_Py_atomic_load_relaxed(&gil->locked)) {
        goto _ready;
    }

    while (_Py_atomic_load_relaxed(&gil->locked)) {
        // 没有拿到gil的情况
        unsigned long saved_switchnum = gil->switch_number;

        unsigned long interval = (gil->interval >= 1 ? gil->interval : 1);
        int timed_out = 0;
        COND_TIMED_WAIT(gil->cond, gil->mutex, interval, timed_out);

        /* If we timed out and no switch occurred in the meantime, it is time
           to ask the GIL-holding thread to drop it. */
        if (timed_out &&
            _Py_atomic_load_relaxed(&gil->locked) &&
            gil->switch_number == saved_switchnum)
        {
            if (tstate_must_exit(tstate)) {
                MUTEX_UNLOCK(gil->mutex);
                PyThread_exit_thread();
            }
            assert(is_tstate_valid(tstate));

            SET_GIL_DROP_REQUEST(interp);
        }
    }

_ready:
    // 省略FORCE_SWITCHING宏相关代码
    
    /* We now hold the GIL */
    _Py_atomic_store_relaxed(&gil->locked, 1);
    _Py_ANNOTATE_RWLOCK_ACQUIRED(&gil->locked, /*is_write=*/1);

    if (tstate != (PyThreadState*)_Py_atomic_load_relaxed(&gil->last_holder)) {
        _Py_atomic_store_relaxed(&gil->last_holder, (uintptr_t)tstate);
        ++gil->switch_number;
    }
    
    // 省略FORCE_SWITCHING宏相关代码
    
    // 省略下面
}
```

我们看到这段逻辑：当`gil`一直被占时，就会进入while循环的`COND_TIMED_WAIT`，等待`gil->cond`的信号。这个信号的通知逻辑是在`drop_gil`的里面的，也就是说如果另一个线程执行了`drop_gil`就会触发这个信号，而由于python的线程是操作系统原生线程，因此我们如果深挖`COND_TIMED_WAIT`内部的实现也可以看到实质上是操作系统在调度信号触发后线程的唤醒。`COND_TIMED_WAIT`的时长是`gil->interval`（也就是`sys.getswitchinterval()`，线程切换时间），过了这段时间还是原来线程hold住`gil`的话，就强制触发`SET_GIL_DROP_REQUEST`逻辑

```c
static inline void
SET_GIL_DROP_REQUEST(PyInterpreterState *interp)
{
    struct _ceval_state *ceval2 = &interp->ceval;
    _Py_atomic_store_relaxed(&ceval2->gil_drop_request, 1);
    _Py_atomic_store_relaxed(&ceval2->eval_breaker, 1);
}
```

我们看到`SET_GIL_DROP_REQUEST`强制激活`gil_drop_request`跟`eval_breaker`，这样持有GIL的线程在`EvalFrame`的时候发现满足`eval_breaker`，就会走`eval_frame_handle_pending`的逻辑，里面再判断有`gil_drop_request`之后，就调用`drop_gil`把解释器锁释放出来。这样，另一个线程在执行`SET_GIL_DROP_REQUEST`之后的某次`COND_TIMED_WAIT`时候，就有可能提前被signal到，之后又发现`gil`没有被locked，于是就能够继续下面的逻辑，持有GIL了。最后，另一个线程拿到了代码的执行权，而原先丢掉GIL的线程，在`eval_frame_handle_pending`再次调用`take_gil`，反过来走在了竞争代码执行权的路上。循环往复，如是而已。

## 总结

通过对线程启动机制、代码运行机制以及基于GIL的线程调度机制的剖析，我们可以“一图流”，解释“python多线程为什么不能并行”这个问题：
![image.png](https://cdn.nlark.com/yuque/0/2021/png/289368/1633435615060-10b135ab-b7c2-465a-82c7-08050c5b37b3.png#clientId=u8166d434-865c-4&from=paste&height=702&id=u10921066&margin=%5Bobject%20Object%5D&name=image.png&originHeight=702&originWidth=783&originalType=binary&ratio=1&size=59582&status=done&style=none&taskId=u1b6695b3-9665-4487-9f68-fe786b9c57b&width=783)
