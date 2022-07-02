---
title: 【Python随笔】掌握子进程subprocess模块的使用方法
date: 2022/07/02 23:38:11
categories:
- Python随笔
tags:
- python
- subprocess
- Popen
- 子进程
- 多进程
---

在`python`开发期间，很多时候我们会需要执行一段`cmd`终端命令，或者是执行其他程序返回`stdout`或者文件输出结果。这种时候，我们就需要用到`subprocess`模块。虽然我们用`os.system`也可以达到执行命令的需求，但用`os.system`只是干发一段命令，对于执行命令的程序，我们没有办法跟踪它的内部状态以及执行结果，因此从稳定性的角度来讲不是一个好的选择。因此，本篇文章讲解下`subprocess`子进程模块的的基础应用，让没用过这个模块或是经常踩坑的同学都避避坑。

`subprocess`模块的官方文档在[这里](https://docs.python.org/3/library/subprocess.html)，最核心的单位是`subprocess.Popen`类，它描述了一个正在运行中的进程。`subprocess`最基础的用法是`subprocess.run`，我们入参一段`cmd`终端命令，`run`方法内部就会启动一个`Popen`对象执行这个命令，等待命令执行结束后，返回这个命令执行的退出码`retcode`，标准输出流内容`stdout`以及标准错误流内容`stderr`。我们可以从源码中详细捋一下`subprocess.run`的流程：

<!-- more -->

```python
def run(*popenargs,
        input=None, capture_output=False, timeout=None, check=False, **kwargs):
    # 忽略上面参数处理部分
    with Popen(*popenargs, **kwargs) as process:  # 新起一个Popen的context
        try:
            # 通过communicate方法拉取最终stdout、stderr的所有数据
            stdout, stderr = process.communicate(input, timeout=timeout)  
        except TimeoutExpired as exc:
            # 超时处理，向os申请杀进程，等待进程结束
            process.kill()
            if _mswindows:
                exc.stdout, exc.stderr = process.communicate()  # communicate也可用来模拟键盘输入
            else:
                process.wait()
            raise
        except:  # Including KeyboardInterrupt, communicate handled that.
            # 向os申请杀进程
            process.kill()
            # We don't call process.wait() as .__exit__ does that for us.
            raise
        retcode = process.poll()  # 获取exitcode
        if check and retcode:
            raise CalledProcessError(retcode, process.args,
                                     output=stdout, stderr=stderr)
    return CompletedProcess(process.args, retcode, stdout, stderr)
```

`subprocess.run`是一个阻塞方法，执行了这个接口后，需要等待`run`入参的命令执行完才能返回。而有些时候，我们需要单独起一个（进程执行）`cmd`命令，然后周期性每几秒钟去检查命令执行的状态，检查完之后我们还可以在主进程干别的事情，也就是搞一个独立出来的进程。这种情况下，`subprocess.run`就无法满足，必须直接开`subprocess.Popen`。

一个基本的示例代码如下：

```python
import subprocess
import platform
import os
import signal


def _decode_bytes(_bytes):
    encoding = 'gbk'
    return _bytes.decode(encoding)


def _decode_stream(stream):
    """windows下解码stdout/stderr的数据"""
    if not stream:
        return ''
    return _decode_bytes(stream.read())


# set params
args = ['ping', '127.0.0.1']  # windows这里不用timeout，因为不支持stdin的重定向，用ping大概3~4s的时间总共
working_directory = '.'  # 支持设置命令的工作目录
wait_timeout = 1  # 命令每周期等待时间
cnt, maxcnt = 0, 4  # 等待次数

# run process
print(f'platform system: {platform.system()}')
p = subprocess.Popen(args,
                     cwd=working_directory,
                     # 设置subprocess.PIPE，这样执行完后可以从p.stdout/p.stderr获取输出数据
                     stdout=subprocess.PIPE,
                     stderr=subprocess.PIPE)
print(f'process args: {args}')
print(f'process pid: {p.pid}')
while cnt < maxcnt:
    try:
        p.wait(timeout=wait_timeout)
    except Exception as e:
        print(f'attempt {cnt} -> wait err: {e}')
        cnt += 1
    finally:
        if p.returncode is not None:  # 看是否有退出码，来判断进程是否执行结束
            break

# check retcode
if p.returncode is None:
    print('[ERROR] retcode is None, maybe timeout, try kill process...')
    if platform.system() == 'Windows':  # windows下，强杀进程用taskkill，因为没有SIGKILL
        kill_proc_ret = subprocess.run(['taskkill', '/f', '/pid', str(p.pid)], capture_output=True)
        print(f'[KILLPROC] {_decode_bytes(kill_proc_ret.stdout)}')
    else:  # 其他情况下可以发送SIGKILL
        os.kill(p.pid, signal.SIGKILL)
else:  # 打印返回数据
    retcode, stdout, stderr = p.returncode, _decode_stream(p.stdout), _decode_stream(p.stderr)
    print(f'[OK] retcode: {retcode}\n\tstdout: {stdout}\n\tstderr: {stderr}')
```

这段程序模拟了周期性等待子进程执行完成的场景，执行完成后拉取`stdout`和`stderr`打印，执行超时就强杀进程。基本上关键的地方都有注释，如果有其他类似的场景，可以直接照搬代码。

最后我们也能看到，`subprocess`本质也是多进程，但和`multiprocessing`有所不同，`multiprocessing`是多个`python`进程，着重于管理多个`python`进程的运行时环境以及之间的通信；而`subprocess`则是侧重于去跟踪`python`程序启动的任意类型进程的状态。两者也有共同点，就是主进程都会持有子进程的`handle`，只要没调用类似`subprocess.run`这种阻塞获取子进程状态/结果的接口，在起了新进程后，主进程内都能够随时随地去获取子进程的状态信息。
