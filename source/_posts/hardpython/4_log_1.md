---
title: 【Hard Python】【第四章-日志】1、Logger与Manager的源码实现
date: 2022/04/09 14:23:10
categories:
- Hard Python
tags:
- python
- 日志
- logging
- Logger
- Manager
---


python语言内置了一个强大的日志模块`logging`，也是python内部最为复杂的功能模块之一，通过这个模块我们能够实现不同样式的日志打印。关于`logging`模块的官方文档也非常完备：

- logging的用法
  - [日志常用指引](https://docs.python.org/zh-cn/3/howto/logging.html#logging-basic-tutorial)
  - [日志操作手册](https://docs.python.org/zh-cn/3/howto/logging-cookbook.html#logging-cookbook)
- logging API
  - [logging日志记录工具](https://docs.python.org/zh-cn/3/library/logging.html#)
  - [logging config](https://docs.python.org/zh-cn/3/library/logging.config.html)
  - [logging handlers](https://docs.python.org/zh-cn/3/library/logging.handlers.html)

为此，本文起我们对python的`logging`模块进行深入剖析，从而让大家能够更好地掌握python的`logging`模块。

<!-- more -->

## 基础配置

我们首先从一段最基本的代码入手：

```python
import logging
import sys


def test_basic_config():
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    logging.info('helloworld')


if __name__ == '__main__':
    test_basic_config()
```

从语义上看，代码的含义是：设置日志基础配置为打印到标准输出流，只接受`INFO`级别以上的日志。很明显，打印出来的结果是：

```text
INFO:root:helloworld
```

我们来看下在源代码里面具体做了什么。首先从`logging.basicConfig`看起，该方法为`logging`系统设定了基础配置。其代码如下：

```python
# logging/__init__.py
def basicConfig(**kwargs):
    _acquireLock()
    try:
        force = kwargs.pop('force', False)
        encoding = kwargs.pop('encoding', None)
        errors = kwargs.pop('errors', 'backslashreplace')
        if force:
            for h in root.handlers[:]:
                root.removeHandler(h)
                h.close()
        if len(root.handlers) == 0:
            handlers = kwargs.pop("handlers", None)
            if handlers is None:
                if "stream" in kwargs and "filename" in kwargs:
                    raise ValueError("'stream' and 'filename' should not be "
                                     "specified together")
            else:
                if "stream" in kwargs or "filename" in kwargs:
                    raise ValueError("'stream' or 'filename' should not be "
                                     "specified together with 'handlers'")
            if handlers is None:
                filename = kwargs.pop("filename", None)
                mode = kwargs.pop("filemode", 'a')
                if filename:
                    if 'b' in mode:
                        errors = None
                    else:
                        encoding = io.text_encoding(encoding)
                    h = FileHandler(filename, mode,
                                    encoding=encoding, errors=errors)
                else:
                    stream = kwargs.pop("stream", None)
                    h = StreamHandler(stream)
                handlers = [h]
            dfs = kwargs.pop("datefmt", None)
            style = kwargs.pop("style", '%')
            if style not in _STYLES:
                raise ValueError('Style must be one of: %s' % ','.join(
                                 _STYLES.keys()))
            fs = kwargs.pop("format", _STYLES[style][1])
            fmt = Formatter(fs, dfs, style)
            for h in handlers:
                if h.formatter is None:
                    h.setFormatter(fmt)
                root.addHandler(h)
            level = kwargs.pop("level", None)
            if level is not None:
                root.setLevel(level)
            if kwargs:
                keys = ', '.join(kwargs.keys())
                raise ValueError('Unrecognised argument(s): %s' % keys)
    finally:
        _releaseLock()
```

传入的参数是`unpacked mapping`式的`kwargs`，会在代码里面被`pop`出来然后根据实际配置值进行配置设定。我们先来看看其中具体由执行哪些逻辑：

- 如果`force`参数被启用，会调用`root.removeHandler`方法清空`handlers`
- `handlers`/`stream`/`filename`的共存检查
  - 可以推测到，这三个概念实际都指代日志的输出目标
- 如果指定`filename`，就创建一个`FileHandler`实例
  - 写入模式、编码错误处理等参数也会从`kwargs`里取出，实际就是`open`里面的参数
- 如果指定`stream`，就创建一个`StreamHandler`实例
- 根据`datefmt`、`style`、`format`配置，创建一个`Formatter`实例，给到所有的`handler`实例
- 根据`level`配置，设置`root`的`level`属性

总的来看，这个流程出现了3个新概念：

- `root`，实际是一个`RootLogger(WARNING)`实例
- `handler`
- `formatter`：是`handler`的属性之一，用来格式化日志信息

本篇文章里面我们首先看`root`，也就是`Logger`相关的内容。后面再看`handler`之类的例子。

## Logger的实现

要看`Logger`，我们可以从`RootLogger`看起，其代码如下：

```python
root = RootLogger(WARNING)
Logger.root = root
Logger.manager = Manager(Logger.root)


class RootLogger(Logger):
    def __init__(self, level):
        Logger.__init__(self, "root", level)

    def __reduce__(self):
        return getLogger, ()
    
    
def getLogger(name=None):
    if not name or isinstance(name, str) and name == root.name:
        return root
    return Logger.manager.getLogger(name)
```

`RootLogger`继承了`Logger`，`__init__`中实际上是创建了名为`root`的`Logger`。此外，`RootLogger`还定义了`__reduce__`函数用于在序列化/反序列化时支持实例的解析。

这里我们能够推测到，`Logger.manager`实例会对`Logger`实例进行管理。因此首先我们看下`Logger`本身，然后再看下`Manager`里面。

我们从打印日志的逻辑看起。假使我们调用`Logger`实例的`info`方法打印日志，实际会涉及到这些代码：

```python
class Logger(Filterer):
    def info(self, msg, *args, **kwargs):
        if self.isEnabledFor(INFO):
            self._log(INFO, msg, args, **kwargs)
    
    def isEnabledFor(self, level):
        if self.disabled:
            return False
        try:
            return self._cache[level]
        except KeyError:
            _acquireLock()
            try:
                if self.manager.disable >= level:
                    is_enabled = self._cache[level] = False
                else:
                    is_enabled = self._cache[level] = (
                        level >= self.getEffectiveLevel()
                    )
            finally:
                _releaseLock()
            return is_enabled
        
    def getEffectiveLevel(self):
        logger = self
        while logger:
            if logger.level:
                return logger.level
            logger = logger.parent
        return NOTSET
```

在`info`逻辑开头，会调用`isEnabledFor`方法判断当前设置的日志级别`level`是否合法。判断的依据是先看`manager`的`disable`设定，然后再看自己是否有设定`level`，如果还没有的话就一直在父`logger`里面找，直到看到设定的`level`，然后进行大小比较。

从这里我们也可以看到，`logger`实例之间是会存在层级关系的。具体后面慢慢说。

之后就会调用`_log`方法真正打印日志，其实现如下：

```python
class Logger(Filterer):
    def _log(self, level, msg, args, exc_info=None, extra=None, stack_info=False,
             stacklevel=1):
        sinfo = None
        if _srcfile:
            try:
                fn, lno, func, sinfo = self.findCaller(stack_info, stacklevel)
            except ValueError: # pragma: no cover
                fn, lno, func = "(unknown file)", 0, "(unknown function)"
        else: # pragma: no cover
            fn, lno, func = "(unknown file)", 0, "(unknown function)"
        if exc_info:
            if isinstance(exc_info, BaseException):
                exc_info = (type(exc_info), exc_info, exc_info.__traceback__)
            elif not isinstance(exc_info, tuple):
                exc_info = sys.exc_info()
        record = self.makeRecord(self.name, level, fn, lno, msg, args,
                                 exc_info, func, extra, sinfo)
        self.handle(record)
        
    def findCaller(self, stack_info=False, stacklevel=1):
        f = currentframe()
        if f is not None:
            f = f.f_back
        orig_f = f
        while f and stacklevel > 1:
            f = f.f_back
            stacklevel -= 1
        if not f:
            f = orig_f
        rv = "(unknown file)", 0, "(unknown function)", None
        while hasattr(f, "f_code"):
            co = f.f_code
            filename = os.path.normcase(co.co_filename)
            if filename == _srcfile:
                f = f.f_back
                continue
            sinfo = None
            if stack_info:
                sio = io.StringIO()
                sio.write('Stack (most recent call last):\n')
                traceback.print_stack(f, file=sio)
                sinfo = sio.getvalue()
                if sinfo[-1] == '\n':
                    sinfo = sinfo[:-1]
                sio.close()
            rv = (co.co_filename, f.f_lineno, co.co_name, sinfo)
            break
        return rv
        
    def makeRecord(self, name, level, fn, lno, msg, args, exc_info,
                   func=None, extra=None, sinfo=None):
        rv = _logRecordFactory(name, level, fn, lno, msg, args, exc_info, func,
                             sinfo)
        if extra is not None:
            for key in extra:
                if (key in ["message", "asctime"]) or (key in rv.__dict__):
                    raise KeyError("Attempt to overwrite %r in LogRecord" % key)
                rv.__dict__[key] = extra[key]
        return rv
    
    def handle(self, record):
        if (not self.disabled) and self.filter(record):
            self.callHandlers(record)
            
    def callHandlers(self, record):
        c = self
        found = 0
        while c:
            for hdlr in c.handlers:
                found = found + 1
                if record.levelno >= hdlr.level:
                    hdlr.handle(record)
            if not c.propagate:
                c = None    #break out
            else:
                c = c.parent
        if (found == 0):
            if lastResort:
                if record.levelno >= lastResort.level:
                    lastResort.handle(record)
            elif raiseExceptions and not self.manager.emittedNoHandlerWarning:
                sys.stderr.write("No handlers could be found for logger"
                                 " \"%s\"\n" % self.name)
                self.manager.emittedNoHandlerWarning = True
```

`_log`执行了三个步骤：

- 通过`findCaller`，找到是哪个文件哪一行代码调用了打印日志
  - 方法是遍历栈帧，检查到第一个非`logging`源代码的调用，从而判断到为实际调用打印日志逻辑的一行
- 通过`makeRecord`，为当前需要打印的日志创建了一个`LogRecord`实例
  - `LogRecord`实例存储了一行日志所需的所有信息，详细实现可以看类定义
- `handle`创建的`LogRecord`实例
  - 首先通过`filter`方法看这个日志`record`能否被打印
    - `filter`的详细实现可以看`Filter`类定义
  - 通过`callHandlers`调用名下所有`handlers`处理`LogRecord`实例，将日志打印到不同的地方
    - 在遍历所有`handler`时也检查`handler`是否能够打印对应等级的日志
    - 如果没有`handler`能打印日志，用特殊的`Logger`实例`lastResort`来兜底

所以我们总结一下`Logger`实例打印日志时的重点：

- 日志记录的生产和消费是分离的
- 生产日志记录需要判断是否符合`Logger`及`Manager`实例的日志级别配置，可能会追溯到上层的`Logger`实例配置
- 消费日志记录首先看是否被`Logger`实例自己过滤掉，然后遍历所有消费者，如果满足日志级别条件即可开始打印操作

## Manager的实现

`Logger`的差不多看完了，接下来我们看一下`Manager`，也就是`Logger`实例的管理器。

```python
class Manager(object):
    def __init__(self, rootnode):
        self.root = rootnode
        self.disable = 0
        self.emittedNoHandlerWarning = False
        self.loggerDict = {}
        self.loggerClass = None
        self.logRecordFactory = None
```

Manager在日志系统内是以单例的形式存在的，其包含如下属性：

- `root`：根`Logger`
- `disable`：禁用日志级别
- `loggerDict`：存储logger实例及对应名称的字典
- `loggerClass`：Logger实例的类
- `logRecordFactory`：日志记录的创建方法，前面有提

`Manager`最大的作用是管理`Logger`实例。通过`getLogger`方法，我们可以获得一个`Logger`实例：

```python
class Manager(object):
    def getLogger(self, name):
        rv = None
        if not isinstance(name, str):
            raise TypeError('A logger name must be a string')
        _acquireLock()
        try:
            if name in self.loggerDict:
                rv = self.loggerDict[name]
                if isinstance(rv, PlaceHolder):
                    ph = rv
                    rv = (self.loggerClass or _loggerClass)(name)
                    rv.manager = self
                    self.loggerDict[name] = rv
                    self._fixupChildren(ph, rv)
                    self._fixupParents(rv)
            else:
                rv = (self.loggerClass or _loggerClass)(name)
                rv.manager = self
                self.loggerDict[name] = rv
                self._fixupParents(rv)
        finally:
            _releaseLock()
        return rv
    
    def _fixupParents(self, alogger):
        name = alogger.name
        i = name.rfind(".")
        rv = None
        while (i > 0) and not rv:
            substr = name[:i]
            if substr not in self.loggerDict:
                self.loggerDict[substr] = PlaceHolder(alogger)
            else:
                obj = self.loggerDict[substr]
                if isinstance(obj, Logger):
                    rv = obj
                else:
                    assert isinstance(obj, PlaceHolder)
                    obj.append(alogger)
            i = name.rfind(".", 0, i - 1)
        if not rv:
            rv = self.root
        alogger.parent = rv
        
    def _fixupChildren(self, ph, alogger):
        name = alogger.name
        namelen = len(name)
        for c in ph.loggerMap.keys():
            #The if means ... if not c.parent.name.startswith(nm)
            if c.parent.name[:namelen] != name:
                alogger.parent = c.parent
                c.parent = alogger
```

如果`Logger`名字没有注册，会触发懒加载`Logger`实例。在懒加载的过程最终，会设定该`Logger`实例所属的父级`Logger`实例。从`_fixupParents`方法可以清楚看到，通过`Logger`名字的.符号能够分隔`Logger`实例所在的层级。如果上一层`Logger`实例不存在，会用一个`PlaceHolder`实例代替，否则会直接赋值`rv`，`break`，然后设置`parent`。

如果`Logger`名字已经注册，且注册的只是一个`PlaceHolder`实例的话，还要额外通过`_fixupChildren`方法，将已定义的子`Logger`绑定到自己身上。

通过这样的实现，就实现了`Logger`实例的管理。
