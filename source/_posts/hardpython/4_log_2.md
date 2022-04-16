---
title: 【Hard Python】【第四章-日志】2、日志消费者Handler的实现
date: 2022/04/16 10:22:53
categories:
- Hard Python
tags:
- python
- 日志
- Handler
- stderr
- TimedRotatingFileHandler
---

在[上篇文章](https://utmhikari.top/2022/04/09/hardpython/4_log_1/)里说完了日志实例`Logger`和日志管理`Manager`，现在该提到`Handler`了。`Handler`是日志信息的消费者，单个`Logger`实例注册多个`Handler`，每生成一个`LogRecord`，就会被合法的`Handler`消费，在不同地方打印出日志信息。

要研究`Handler`，首先需要看下基类的实现：

```python
class Handler(Filterer):
    def handle(self, record):
        rv = self.filter(record)
        if rv:
            self.acquire()
            try:
                self.emit(record)
            finally:
                self.release()
        return rv
```

`Handler`会通过自带的重入锁限制日志记录被串行处理。`Handler`也是继承`Filterer`，首先会通过`filter`过滤日志是否满足`Handler`的要求，如果合法，然后调用`emit`方法处理日志。

`emit`方法在基类是`NotImplemented`，需要子类加以实现。因此接下来我们具体抽几个例子来看。

<!-- more -->

## StreamHandler

`StreamHandler`打印日志的实现比较简单：

```python
class StreamHandler(Handler):
    terminator = '\n'
    
    def emit(self, record):
        try:
            msg = self.format(record)
            stream = self.stream
            # issue 35046: merged two stream.writes into one.
            stream.write(msg + self.terminator)
            self.flush()
        except RecursionError:  # See issue 36272
            raise
        except Exception:
            self.handleError(record)
            
    def flush(self):
        self.acquire()
        try:
            if self.stream and hasattr(self.stream, "flush"):
                self.stream.flush()
        finally:
            self.release()
```

`StreamHandler`默认的`stream`是`sys.stderr`。只要我们在`basicConfig`中给到的`stream`实例实现了`write`跟`flush`方法，就可以被放到`StreamHandler`里头处理日志。日志首先通过`format`方法被`Handler`实例的`formatter`格式化，然后再被输出。

以`sys.stderr`为例，我们来看标准错误流在`python`中的源码实现。首先需要追溯`sys.stderr`的来源，我们节选一部分代码：

```c
// pylifecycle.c
static PyStatus
init_sys_streams(PyThreadState *tstate)
{
    fd = fileno(stderr);
    std = create_stdio(config, iomod, fd, 1, "<stderr>",
                       config->stdio_encoding,
                       L"backslashreplace");
    if (PySys_SetObject("__stderr__", std) < 0) {
        Py_DECREF(std);
        goto error;
    }
    if (_PySys_SetObjectId(&PyId_stderr, std) < 0) {
        Py_DECREF(std);
        goto error;
    }
    Py_DECREF(std);
}


static PyObject*
create_stdio(const PyConfig *config, PyObject* io,
    int fd, int write_mode, const char* name,
    const wchar_t* encoding, const wchar_t* errors)
{
    buf = _PyObject_CallMethodId(io, &PyId_open, "isiOOOO",
                                 fd, mode, buffering,
                                 Py_None, Py_None, /* encoding, errors */
                                 Py_None, Py_False); /* newline, closefd */
    stream = _PyObject_CallMethodId(io, &PyId_TextIOWrapper, "OOOsOO",
                                    buf, encoding_str, errors_str,
                                    newline, line_buffering, write_through);
}
```

在`pylifecycle.c`中，`sys.stderr`被设置，最终调用了`create_stdio`设置了`stream`实例。其中，会调用`io`模块的`open`以及`TextIOWrapper`方法：

```c
// _iomodule.c
static PyObject *
_io_open_impl(PyObject *module, PyObject *file, const char *mode,
              int buffering, const char *encoding, const char *errors,
              const char *newline, int closefd, PyObject *opener)
{
    /* Create the Raw file stream */
    {
        PyObject *RawIO_class = (PyObject *)&PyFileIO_Type;
#ifdef MS_WINDOWS
        const PyConfig *config = _Py_GetConfig();
        if (!config->legacy_windows_stdio && _PyIO_get_console_type(path_or_fd) != '\0') {
            RawIO_class = (PyObject *)&PyWindowsConsoleIO_Type;
            encoding = "utf-8";
        }
#endif
        raw = PyObject_CallFunction(RawIO_class, "OsOO",
                                    path_or_fd, rawmode,
                                    closefd ? Py_True : Py_False,
                                    opener);
    }
    
    /* wraps into a buffered file */
    {
        PyObject *Buffered_class;

        if (updating)
            Buffered_class = (PyObject *)&PyBufferedRandom_Type;
        else if (creating || writing || appending)
            Buffered_class = (PyObject *)&PyBufferedWriter_Type;  // hits here
        else if (reading)
            Buffered_class = (PyObject *)&PyBufferedReader_Type;
        else {
            PyErr_Format(PyExc_ValueError,
                         "unknown mode: '%s'", mode);
            goto error;
        }

        buffer = PyObject_CallFunction(Buffered_class, "Oi", raw, buffering);
    }
    if (buffer == NULL)
        goto error;
    result = buffer;
    
    /* if binary, returns the buffered file */
    if (binary) {
        Py_DECREF(modeobj);
        return result;
    }
}
```

所以总的来看，在`windows`中，`stderr`实例的创建流程大致是这样：

- 创建了一个`PyWindowsConsoleIO_Type`的实例
  - `PyWindowsConsoleIO_Type`实质是封装了和`windows`命令行终端交互的方法
- 创建了一个`PyBufferedWriter_Type`实例去实现缓冲输出流
  - 该实例的`raw`属性即为`PyWindowsConsoleIO_Type`的实例
- 创建了一个`TextIOWrapper`实例封装`PyBufferedWriter_Type`实例，得到`stderr`的`stream`实例

当调用`stderr.write`和`stderr.flush`时，最终会调用`BufferedWriter`的`write`和`flush`。在`write`过程中会将数据写入缓冲区，而在`write`跟`flush`过程中都会调用`raw.write`方法尝试将缓冲区数据刷掉，并写入`windows`命令行。有兴趣的同学，可以深入研究`bufferedio.c`里面的内容。

## FileHandler

`FileHandler`继承了`StreamHandler`，可以将日志记录打印到文件里面，其代码如下：

```python
class FileHandler(StreamHandler):
    def __init__(self, filename, mode='a', encoding=None, delay=False, errors=None):
        filename = os.fspath(filename)
        self.baseFilename = os.path.abspath(filename)
        self.mode = mode
        self.encoding = encoding
        if "b" not in mode:
            self.encoding = io.text_encoding(encoding)
        self.errors = errors
        self.delay = delay
        self._builtin_open = open
        if delay:
            Handler.__init__(self)
            self.stream = None
        else:
            StreamHandler.__init__(self, self._open())
        
    def _open(self):
        open_func = self._builtin_open
        return open_func(self.baseFilename, self.mode,
                         encoding=self.encoding, errors=self.errors)
    
    def emit(self, record):
        if self.stream is None:
            self.stream = self._open()
        StreamHandler.emit(self, record)
```

`FileHandler`为`StreamHandler`底层提供了一个内置`open`方法文件流。我们知道这样的文件流也会有`write`以及`flush`方法，所以显而易见日志会输出到对应的文件当中。

## TimedRotatingFileHandler

`TimedRotatingFileHandler`也是常用的日志`Handler`之一，它可以实现按规定的时间间隔打印各个时段的日志到不同文件中。其继承链如下：

```text
# pprint.pprint(TimedRotatingFileHandler.__mro__)
(<class 'logging.handlers.TimedRotatingFileHandler'>,
 <class 'logging.handlers.BaseRotatingHandler'>,
 <class 'logging.FileHandler'>,
 <class 'logging.StreamHandler'>,
 <class 'logging.Handler'>,
 <class 'logging.Filterer'>,
 <class 'object'>)
```

首先我们来看`BaseRotatingHandler`，它继承了`FileHandler`，其实现如下：

```python
class BaseRotatingHandler(logging.FileHandler):
    def emit(self, record):
        try:
            if self.shouldRollover(record):
                self.doRollover()
            logging.FileHandler.emit(self, record)
        except Exception:
            self.handleError(record)
            
    def rotate(self, source, dest):
        if not callable(self.rotator):
            if os.path.exists(source):
                os.rename(source, dest)
        else:
            self.rotator(source, dest)
```

`BaseRotatingHandler`在打印日志记录前，首先会通过`shouldRollover`方法根据日志记录信息判断是否要翻篇，如果需要的话就调用`doRollOver`方法翻篇，最后再调用`FileHandler`的`emit`方法。`shouldRollover`跟`doRollover`方法都需要子类自己实现。

同时，`BaseRotatingHandler`也提供了`rotate`方法调用`rotator`或者采用默认重命名的方式执行翻篇操作。

接下来我们再看`TimedRotatingFileHandler`的具体实现：

```python
class TimedRotatingFileHandler(BaseRotatingHandler):
    def __init__(self, filename, when='h', interval=1, backupCount=0,
                 encoding=None, delay=False, utc=False, atTime=None,
                 errors=None):
        if os.path.exists(filename):
            t = os.stat(filename)[ST_MTIME]
        else:
            t = int(time.time())
        self.rolloverAt = self.computeRollover(t)
        
    def computeRollover(self, currentTime):
        result = currentTime + self.interval
        if self.when == 'MIDNIGHT' or self.when.startswith('W'):
            # 这里忽略掉计算凌晨跟一周内特定日的情况
            pass
        return result
        
    def shouldRollover(self, record):
        t = int(time.time())
        if t >= self.rolloverAt:
            return 1
        return 0
    
    def doRollover(self):
        if self.stream:
            self.stream.close()
            self.stream = None
        # get the time that this sequence started at and make it a TimeTuple
        currentTime = int(time.time())
        dstNow = time.localtime(currentTime)[-1]
        t = self.rolloverAt - self.interval
        if self.utc:
            timeTuple = time.gmtime(t)
        else:
            timeTuple = time.localtime(t)
            dstThen = timeTuple[-1]
            if dstNow != dstThen:
                if dstNow:
                    addend = 3600
                else:
                    addend = -3600
                timeTuple = time.localtime(t + addend)
        dfn = self.rotation_filename(self.baseFilename + "." +
                                     time.strftime(self.suffix, timeTuple))
        if os.path.exists(dfn):
            os.remove(dfn)
        self.rotate(self.baseFilename, dfn)
        if self.backupCount > 0:
            for s in self.getFilesToDelete():
                os.remove(s)
        if not self.delay:
            self.stream = self._open()
        newRolloverAt = self.computeRollover(currentTime)
        while newRolloverAt <= currentTime:
            newRolloverAt = newRolloverAt + self.interval
        #If DST changes and midnight or weekly rollover, adjust for this.
        if (self.when == 'MIDNIGHT' or self.when.startswith('W')) and not self.utc:
            dstAtRollover = time.localtime(newRolloverAt)[-1]
            if dstNow != dstAtRollover:
                if not dstNow:  # DST kicks in before next rollover, so we need to deduct an hour
                    addend = -3600
                else:           # DST bows out before next rollover, so we need to add an hour
                    addend = 3600
                newRolloverAt += addend
        self.rolloverAt = newRolloverAt
```

在初始化的过程中，首先会解析时间设定计算时间间隔`interval`，然后通过`computeRollover`初始化`rolloverAt`，也就是翻篇的时间点。在`emit`的时候，也会直接通过当前时间判断是否超过翻篇时间，超过的话，就会执行`doRollover`。

`doRollover`总共做了这么几件事情：

- 关闭当前文件流
- 根据当前时间生成需要归档的日志文件名
- 执行翻篇，将当前日志文件重命名，归档标注为特定时间
- 删除冗余的旧文件
- 如果不是lazy-load，直接调用`_open`生成新的文件
- 计算新的翻篇时间点

可以看到，`baseFilename`其实是个中间态的文件名，实质翻篇操作会是重命名文件，修改为带特定时间信息的文件名。

## 总结

在`logging.handlers`里，除了上述三种`handler`外，还有许许多多的`handler`定义。有兴趣的同学可以自行挖掘！
