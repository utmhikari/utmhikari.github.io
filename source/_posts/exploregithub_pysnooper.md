---
title: 【探索GitHub】python调试利器——pysnooper源码分析
date: 2019/05/25 01:29:38
categories:
- 探索GitHub
tags:
- python
- pysnooper
- 逆向
- 源码分析
- debug
---

## 前言

这次又开了个新坑——探索Github，主要内容是试水当期github上较火的repo

虽然top榜上各路新手教程跟经典老不死项目占据了大半江山，但清流总是会有的。

第一期就试水一下[pysnooper](https://github.com/cool-RR/PySnooper)吧，一个新奇实用的python调试器。

顺便源码分析一波，了解下python的debug操作。

废话不多说，进入正题~

<!-- more -->

## pysnooper使用效果

通常，我们可以在函数上用`pysnooper.snoop`装饰器，给这个函数包装一个额外功能，实现在标准错误流打印函数debug信息的效果。比如说：

```python
@pysnooper.snoop(depth=2)
def factorial(x):
    if x == 0:
        return 1
    return mul(
        x,
        factorial(x - 1)
    )


def mul(a, b):
    return a * b


def main():
    factorial(2)
```

执行main的效果就是：

```plain
Starting var:.. x = 2
22:24:25.476753 call         5 def factorial(x):
22:24:25.476753 line         6     if x == 0:
22:24:25.476753 line         8     return mul(
22:24:25.476753 line         9         x,
22:24:25.476753 line        10         factorial(x - 1)
    Starting var:.. x = 1
    22:24:25.477743 call         5 def factorial(x):
    22:24:25.477743 line         6     if x == 0:
    22:24:25.477743 line         8     return mul(
    22:24:25.477743 line         9         x,
    22:24:25.477743 line        10         factorial(x - 1)
        Starting var:.. x = 0
        22:24:25.477743 call         5 def factorial(x):
        22:24:25.477743 line         6     if x == 0:
        22:24:25.477743 line         7         return 1
        22:24:25.477743 return       7         return 1
        Return value:.. 1
        Starting var:.. a = 1
        Starting var:.. b = 1
        22:24:25.477743 call        15 def mul(a, b):
        22:24:25.477743 line        16     return a * b
        22:24:25.477743 return      16     return a * b
        Return value:.. 1
    22:24:25.477743 return      10         factorial(x - 1)
    Return value:.. 1
    Starting var:.. a = 2
    Starting var:.. b = 1
    22:24:25.477743 call        15 def mul(a, b):
    22:24:25.477743 line        16     return a * b
    22:24:25.477743 return      16     return a * b
    Return value:.. 2
22:24:25.477743 return      10         factorial(x - 1)
Return value:.. 2
```

这样我们就可以trace到整一个函数相关的流程了，非常方便，可以很好地代替print的工作。

## pysnooper实现原理

pysnooper的实现涉及到python底层debug相关的知识。在以前写过的一篇[lua的debug库源码分析](https://utmhikari.github.io/2019/04/07/luatalk_lfunctimer_capi/)中提到了lua获取debug信息的相关操作，而pysnooper实现上也是通过获取底层信息进行debug trace，从结果上来看，也收集了call、line、return以及变量定义之类的操作事件信息。虽然语言不同，但基本思想都一样滴~

因此，在逆向pyssnooper实现原理之时，也将先入为主地代入一些lua的相关概念。

pysnooper相关的参考资料，基本可以在python标准库中的[inspect库文档](https://docs.python.org/3/library/inspect.html)中找到~

调用的`pysnooper.snoop`定义在pysnooper的`__init__.py`中：

```python
from .tracer import Tracer as snoop
```

因此我们直接转向Tracer类一探究竟

```python
def __call__(self, function):
    self.target_codes.add(function.__code__)

    @functools.wraps(function)
    def simple_wrapper(*args, **kwargs):
        with self:
            return function(*args, **kwargs)

    @functools.wraps(function)
    def generator_wrapper(*args, **kwargs):
        gen = function(*args, **kwargs)
        method, incoming = gen.send, None
        while True:
            with self:
                try:
                    outgoing = method(incoming)
                except StopIteration:
                    return
            try:
                method, incoming = gen.send, (yield outgoing)
            except Exception as e:
                method, incoming = gen.throw, e

    if pycompat.iscoroutinefunction(function):
        # return decorate(function, coroutine_wrapper)
        raise NotImplementedError
    elif inspect.isgeneratorfunction(function):
        return generator_wrapper
    else:
            return simple_wrapper
```

作为一个装饰器首先要实现的是各类函数的包装。pysnooper首先将该函数编译的代码`__code__`进行备份，而后根据情况封装函数。pysnooper暂时没有对协程（async def task/coroutine）做封装，但对于一般函数跟generator，都把函数体内所有的操作包裹在了Tracer自己的with作用域中。

在日常码码中，我们写到with的场景一般是文件io操作，或者是tensorflow之类。with作用域提供了`__enter__`与`__exit__`两个元方法，定义进出作用域时的相关操作。

```python
def __enter__(self):
    calling_frame = inspect.currentframe().f_back
    if not self._is_internal_frame(calling_frame):
        calling_frame.f_trace = self.trace
        self.target_frames.add(calling_frame)

    stack = self.thread_local.__dict__.setdefault('original_trace_functions', [])
    stack.append(sys.gettrace())
    sys.settrace(self.trace)

def __exit__(self, exc_type, exc_value, exc_traceback):
    stack = self.thread_local.original_trace_functions
    sys.settrace(stack.pop())
    calling_frame = inspect.currentframe().f_back
    self.target_frames.discard(calling_frame)
    self.frame_to_local_reprs.pop(calling_frame, None)

def _is_internal_frame(self, frame):
    return frame.f_code.co_filename == Tracer.__enter__.__code__.co_filename
```

可以看到，每当发生进出Tracer作用域的时候（也就是封装function的时候）都会发生一些类似状态管理的操作。因此首先稍微厘清一些概念:

- frame：相当于lua的callinfo，表示python调用栈上的函数信息
- thread_local：当前线程作用域（Java同学应该都明白）
- trace：相当于lua的hook

可以看到，每次`__enter__`时，增加统计frame信息，并且在当前线程建立一个trace栈记录每个函数上一个frame（调用该函数的frame）的trace函数。
然后反过来，每次`__exit__`时，trace函数重置为上一个（从trace栈中pop出来），同时移除统计的frame，从而维持原有的状态。

最后我们直接看trace（hook）函数，了解pysnooper打印操作具体实现：

```python
def trace(self, frame, event, arg):
    ### Checking whether we should trace this line: #######################
    #                                                                     #
    # We should trace this line either if it's in the decorated function,
    # or the user asked to go a few levels deeper and we're within that
    # number of levels deeper.

    if not (frame.f_code in self.target_codes or frame in self.target_frames):
        if self.depth == 1:
            # We did the most common and quickest check above, because the
            # trace function runs so incredibly often, therefore it's
            # crucial to hyper-optimize it for the common case.
            return None
        elif self._is_internal_frame(frame):
            return None
        else:
            _frame_candidate = frame
            for i in range(1, self.depth):
                _frame_candidate = _frame_candidate.f_back
                if _frame_candidate is None:
                    return None
                elif _frame_candidate.f_code in self.target_codes or _frame_candidate in self.target_frames:
                    break
            else:
                return None

    thread_global.__dict__.setdefault('depth', -1)
    if event == 'call':
        thread_global.depth += 1
    indent = ' ' * 4 * thread_global.depth

    #                                                                     #
    ### Finished checking whether we should trace this line. ##############
```

python规定trace函数包含三个参数：frame、event与arg，frame代表当前调用栈的frame；event是运行时事件，比lua多了exception与opcode两个；arg是受控于event的只读参数。

在pysnooper的trace函数中，首先针对是否记录/打印数据进行判断，只有当前frame或者其上层frame在要测的frames里或者包含要测的代码块，才会被纳入pysnooper记录当中。
判断完之后，就规定每一个函数调用事件发生时，打印增加4位缩进。

```python
def get_local_reprs(frame, watch=()):
    code = frame.f_code
    vars_order = code.co_varnames + code.co_cellvars + code.co_freevars + tuple(frame.f_locals.keys())
    result_items = [(key, utils.get_shortish_repr(value)) for key, value in frame.f_locals.items()]
    result_items.sort(key=lambda key_value: vars_order.index(key_value[0]))
    result = collections.OrderedDict(result_items)
    for variable in watch:
        result.update(sorted(variable.items(frame)))
    return result


def trace(...):
    # 接上
    ### Reporting newish and modified variables: ##########################
    #                                                                     #
    old_local_reprs = self.frame_to_local_reprs.get(frame, {})
    self.frame_to_local_reprs[frame] = local_reprs = \
        get_local_reprs(frame, watch=self.watch)
    newish_string = ('Starting var:.. ' if event == 'call' else
                        'New var:....... ')
    for name, value_repr in local_reprs.items():
        if name not in old_local_reprs:
            self.write('{indent}{newish_string}{name} = {value_repr}'.format(
                **locals()))
        elif old_local_reprs[name] != value_repr:
            self.write('{indent}Modified var:.. {name} = {value_repr}'.format(
                **locals()))

    #                                                                     #
    ### Finished newish and modified variables. ###########################
```

而后，对当前frame的变量状态进行分析。如果有新的变量，则标明新变量或者调用参数；如果有变量跟上一次值不一样，则标明修改了一个变量。

```python
def trace(...):
    # 接上
    now_string = datetime_module.datetime.now().time().isoformat()
    line_no = frame.f_lineno
    source_line = get_source_from_frame(frame)[line_no - 1]
    thread_info = ""
    if self.thread_info:
        current_thread = threading.current_thread()
        thread_info = "{ident}-{name} ".format(
            ident=current_thread.ident, name=current_thread.getName())
    thread_info = self.set_thread_info_padding(thread_info)

    ### Dealing with misplaced function definition: #######################
    #                                                                     #
    if event == 'call' and source_line.lstrip().startswith('@'):
        # If a function decorator is found, skip lines until an actual
        # function definition is found.
        for candidate_line_no in itertools.count(line_no):
            try:
                candidate_source_line = \
                    get_source_from_frame(frame)[candidate_line_no - 1]
            except IndexError:
                # End of source file reached without finding a function
                # definition. Fall back to original source line.
                break

            if candidate_source_line.lstrip().startswith('def'):
                # Found the def line!
                line_no = candidate_line_no
                source_line = candidate_source_line
                break
    #                                                                     #
    ### Finished dealing with misplaced function definition. ##############
```

然后，除去新建变量/修改变量之外，其它的日志都打印当前时间、event、源码以及线程信息。

对于装饰器，则暂且跳过，寻找真正的函数声明。

```python
def trace(...):
    # 接上
    # If a call ends due to an exception, we still get a 'return' event
    # with arg = None. This seems to be the only way to tell the difference
    # https://stackoverflow.com/a/12800909/2482744
    code_byte = frame.f_code.co_code[frame.f_lasti]
    if not isinstance(code_byte, int):
        code_byte = ord(code_byte)
    ended_by_exception = (
            event == 'return'
            and arg is None
            and (opcode.opname[code_byte]
                    not in ('RETURN_VALUE', 'YIELD_VALUE'))
    )

    if ended_by_exception:
        self.write('{indent}Call ended by exception'.
                    format(**locals()))
    else:
        self.write(u'{indent}{now_string} {thread_info}{event:9} '
                    u'{line_no:4} {source_line}'.format(**locals()))

    if event == 'return':
        del self.frame_to_local_reprs[frame]
        thread_global.depth -= 1

        if not ended_by_exception:
            return_value_repr = utils.get_shortish_repr(arg)
            self.write('{indent}Return value:.. {return_value_repr}'.
                        format(**locals()))

    if event == 'exception':
        exception = '\n'.join(traceback.format_exception_only(*arg[:2])).strip()
        exception = utils.truncate(exception, utils.MAX_EXCEPTION_LENGTH)
        self.write('{indent}{exception}'.
                    format(**locals()))

    return self.trace
```

最后就是return跟exception的判定，两者有一定的交集（可见上面注释），因此根据不同情况从当前作用域变量表`locals()`提取不同变量打印不同信息。这里也不需细述。

总体看来，pysnooper提供的hook还是非常轻量实用的。虽然存在这兼容async task跟自定义hook（trace）的问题，但在平时debug中已经可以满足许多需求了。

## 总结

以前写python的时间算起来应该是最多的，但是python调试相关的工作都没有好好研究过，说来也有点小惭愧。

这次借着试水pysnooper的机会，涨了许多见识，也顺便对python底层有了初步的了解。

虽然自己习惯肉眼debug，但pysnooper作为一个debug黑科技，还是相当给力！！！