---
title: 【Hard Python】【第一章-多进程】1、Process，新进程的诞生
date: 2022/01/16 18:36:17
categories:
- Hard Python
tags:
- python
- multiprocessing
- Process
- 多进程
- spawn
---

在python中，如果要做多任务并行的编程，必须要掌握`multiprocessing`库的相关运用。在python的[multiprocessing官方文档](https://docs.python.org/zh-cn/3/library/multiprocessing.html)中，已然详细给出了`multiprocessing`库的相关用法。多进程编程其实还是有很多坑存在的，为了进一步探索python多进程的机制，提升对python多进程编程的理解，本篇文章会对多进程模块的实现进行一次详细的剖析。

多进程编程的第一话，首先来聊聊一个新的python子进程是如何诞生的。

首先我们需要了解这么一个事情，python创建的进程之间模块状态是相互隔离的。在多进程的场景下，代码中定义的各种变量，其值并不一定会共享。我们举个例子：

<!-- more -->

```python
import multiprocessing as mp
import threading
import os

# 这只是另外一个模块，里头有个变量FLAG，默认是0，init之后是-1
import mp_module

"""
# mp_module.py
FLAG = -1


def get_flag():
    return FLAG


def init_flag():
    global FLAG
    FLAG = 1
"""


def _test_module_isolation():
    from multiprocessing import process
    parent = process.parent_process()
    if parent:
        print(f'[{os.getpid()}] {parent.pid}')
    print(f'[{os.getpid()}] [{threading.current_thread()}] {mp_module.get_flag()}')


def test_module_isolation():
    print(f'main process pid: {os.getpid()}')

    p = mp.Process(target=_test_module_isolation)
    p.start()

    _test_module_isolation()
    p.join()
    

if __name__ == '__main__':
    mp.set_start_method('spawn')
    mp_module.init_flag()
    test_module_isolation()
```

在函数`test_module_isolation`中，首先是调用`mp_module.init_flag()`改变了`mp_module`模块一个变量的值，之后同时在主进程和新起的进程调用了`_test_module_isolation()`去打印`mp_module`中的变量。结果如下：

```text
main process pid: 14836
[14836] [<_MainThread(MainThread, started 20244)>] 1
[22212] 14836
[22212] [<_MainThread(MainThread, started 23804)>] -1
```

可以看到，主进程（14836）中打印出来的变量是初始化过的，而子进程（22212）打印出来的变量是没有经过初始化的。

通过`Process`实例创建出来的进程对象，调用`start`方法即可启动新进程，执行`target`对应的方法。

```python
# BaseProcess.start
def start(self):
    '''
        Start child process
        '''
    self._check_closed()
    assert self._popen is None, 'cannot start a process twice'
    assert self._parent_pid == os.getpid(), \
    'can only start a process object created by current process'
    assert not _current_process._config.get('daemon'), \
    'daemonic processes are not allowed to have children'
    _cleanup()
    self._popen = self._Popen(self)
    self._sentinel = self._popen.sentinel
    # Avoid a refcycle if the target function holds an indirect
    # reference to the process object (see bpo-30775)
    del self._target, self._args, self._kwargs
    _children.add(self)

# Process._Popen
class SpawnProcess(process.BaseProcess):
    _start_method = 'spawn'
    @staticmethod
    def _Popen(process_obj):
        from .popen_spawn_win32 import Popen
        return Popen(process_obj)
```

创建进程的方式有多种，其中`spawn`模式为windows/linux系统下均兼容的，且为windows的默认模式。在`Process._Popen`中，会通过`_default_context.get_context()`获取当前的进程启动模式。

以windows下的`spawn`模式为例，我们看下进程启动的代码的实现。主要逻辑分布在3个地方：

- `popen_spawn_win32.Popen`
- `multiprocessing/spawn.py`
- `process.BaseProcess`

```python
# popen_fork.Popen
class Popen(object):
    def __init__(self, process_obj):
        util._flush_std_streams()
        self.returncode = None
        self.finalizer = None
        self._launch(process_obj)
        
# popen_spawn_win32.Popen
class Popen(object):
    method = 'spawn'

    def __init__(self, process_obj):
        prep_data = spawn.get_preparation_data(process_obj._name)

        rhandle, whandle = _winapi.CreatePipe(None, 0)
        wfd = msvcrt.open_osfhandle(whandle, 0)
        cmd = spawn.get_command_line(parent_pid=os.getpid(),
                                     pipe_handle=rhandle)
        cmd = ' '.join('"%s"' % x for x in cmd)

        python_exe = spawn.get_executable()

        if WINENV and _path_eq(python_exe, sys.executable):
            python_exe = sys._base_executable
            env = os.environ.copy()
            env["__PYVENV_LAUNCHER__"] = sys.executable
        else:
            env = None

        with open(wfd, 'wb', closefd=True) as to_child:
            # start process
            try:
                hp, ht, pid, tid = _winapi.CreateProcess(
                    python_exe, cmd,
                    None, None, False, 0, env, None, None)
                _winapi.CloseHandle(ht)
            except:
                _winapi.CloseHandle(rhandle)
                raise

            # set attributes of self
            self.pid = pid
            self.returncode = None
            self._handle = hp
            self.sentinel = int(hp)
            self.finalizer = util.Finalize(self, _close_handles,
                                           (self.sentinel, int(rhandle)))

            # send information to child
            set_spawning_popen(self)
            try:
                reduction.dump(prep_data, to_child)
                reduction.dump(process_obj, to_child)
            finally:
                set_spawning_popen(None)
                
                
# multiprocessing/spawn.py
def get_command_line(**kwds):
    if getattr(sys, 'frozen', False):
        return ([sys.executable, '--multiprocessing-fork'] +
                ['%s=%r' % item for item in kwds.items()])
    else:
        prog = 'from multiprocessing.spawn import spawn_main; spawn_main(%s)'
        prog %= ', '.join('%s=%r' % item for item in kwds.items())
        opts = util._args_from_interpreter_flags()
        return [_python_exe] + opts + ['-c', prog, '--multiprocessing-fork']


def spawn_main(pipe_handle, parent_pid=None, tracker_fd=None):
    assert is_forking(sys.argv), "Not forking"
    if sys.platform == 'win32':
        import msvcrt
        import _winapi

        if parent_pid is not None:
            source_process = _winapi.OpenProcess(
                _winapi.SYNCHRONIZE | _winapi.PROCESS_DUP_HANDLE,
                False, parent_pid)
        else:
            source_process = None
        new_handle = reduction.duplicate(pipe_handle,
                                         source_process=source_process)
        fd = msvcrt.open_osfhandle(new_handle, os.O_RDONLY)
        parent_sentinel = source_process
    else:
        from . import resource_tracker
        resource_tracker._resource_tracker._fd = tracker_fd
        fd = pipe_handle
        parent_sentinel = os.dup(pipe_handle)
    exitcode = _main(fd, parent_sentinel)
    sys.exit(exitcode)


def _main(fd, parent_sentinel):
    with os.fdopen(fd, 'rb', closefd=True) as from_parent:
        process.current_process()._inheriting = True
        try:
            preparation_data = reduction.pickle.load(from_parent)
            prepare(preparation_data)
            self = reduction.pickle.load(from_parent)
        finally:
            del process.current_process()._inheriting
    return self._bootstrap(parent_sentinel)


# process.BaseProcess
class BaseProcess(object):
    def _bootstrap(self, parent_sentinel=None):
        # 忽略
        try:
            # 忽略，设置一些参数
            try:
                self.run()
                exitcode = 0
            finally:
                util._exit_function()
        except SystemExit as e:
            if e.code is None:
                exitcode = 0
            elif isinstance(e.code, int):
                exitcode = e.code
            else:
                sys.stderr.write(str(e.code) + '\n')
                exitcode = 1
        except:
            exitcode = 1
            # 忽略，打印错误信息
        finally:
            threading._shutdown()
            util.info('process exiting with exitcode %d' % exitcode)
            util._flush_std_streams()

        return exitcode
    
    def run(self):
        if self._target:
            self._target(*self._args, **self._kwargs)
```

这里经历了以下几个步骤：

- 用`_winapi.CreatePipe`创建一对用于进程间通信的`handle`
  - `rhandle`会传给子进程，`whandle`会被主进程用于给子进程发送数据
- 获取构建子进程运行时环境所需要的准备数据`prep_data`
  - 包括`sys.argv`、`sys.path`、日志配置、初始化`__main__`模块的文件路径等
- 通过`spawn.get_command_line`初始化`spawn`进程所需的命令
  - 从函数定义中可以看到，子进程执行的命令中会调用`spawn.spawn_main`函数
- 调用`_winapi.CreateProcess`生成子进程
- 通过`whandle`转换后的fd向子进程写入序列化后的准备数据以及自身`Process`实例数据
- 子进程在`spawn_main`函数将传入的`rhandle`转化为fd，在`_main`函数中接收主进程传入的数据，并执行对应操作
  - 接收`prep_data`，初始化子进程运行时环境。其中会重新执行原来`__main__`模块对应的代码块
    - 这里注意，子进程执行原来`__main__`模块的代码块，是以`__mp_main__`这个模块名执行的。因此，原来代码里头`if __name__ == '__main__'`下面的都执行不到。所以，子进程跑不到`mp_module.init_flag()`，里面的`flag`值当然没有被初始化。如果要让`flag`被初始化的话，相信聪明的你知道怎么做。
  - 执行`Process`实例的`_bootstrap`函数。`_bootstrap`函数最终调用`run`函数，执行`_target`对应的内容

这样，新的python进程就被创建并开始运行了。
