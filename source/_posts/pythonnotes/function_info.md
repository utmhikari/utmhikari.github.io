---
title: 【Python随笔】如何提取python函数的接口定义信息
date: 2021/12/12 15:36:56
categories:
- Python随笔
tags:
- python
- inspect
- dir
- typing
- 反射
---

在某些python框架底层的开发需求中，需要通过一些类似反射的手段，提取函数接口的信息，从而对一系列函数接口进行管理。本篇文章就来粗浅谈一下，如何提取python函数的接口定义信息。

## function对象的信息

首先我们拿一个函数来试试手：

```python
def myprinter(s: str, /, e: str = '\n', *, prefix: Any = '') -> Tuple[bool, str]:
    """hello world"""
    msg = str(prefix) + s + e
    print(msg, end='')
    return True, msg
```

这个函数`myprinter`采用了新的语法糖`/`以及`*`，`/`的左边表示强制位置参数（positional-only arguments），`*`的右边表示强制关键字参数（keyword-only arguments），而两者中间的参数在使用时以位置参数或者是关键字参数的形式表达都可以。

要提取这个函数的信息，我们首先要知道函数本身也是一种对象。因此，可以用到`dir`函数，遍历这个对象的属性，从而提取所有属性的值。

通过`dir`导出函数对象的属性与值，打印的结果如下：

<!-- more -->

```text
{'__annotations__': {'e': <class 'str'>,
                     'prefix': typing.Any,
                     'return': typing.Tuple[bool, str],
                     's': <class 'str'>},
 '__call__': <method-wrapper '__call__' of function object at 0x000001C78C54F040>,
 '__class__': <class 'function'>,
 '__closure__': None,
 '__code__': <code object myprinter at 0x000001C78CC823A0, file "H:\Projects\Python\playground\datastruct\functionobj.py", line 11>,
 '__defaults__': ('\n',),
 '__delattr__': <method-wrapper '__delattr__' of function object at 0x000001C78C54F040>,
 '__dict__': {},
 '__dir__': [函数对象的属性列表，其实就打印的这些，不再重复列举了],
 '__doc__': 'hello world',
 '__eq__': <method-wrapper '__eq__' of function object at 0x000001C78C54F040>,
 '__format__': <built-in method __format__ of function object at 0x000001C78C54F040>,
 '__ge__': <method-wrapper '__ge__' of function object at 0x000001C78C54F040>,
 '__get__': <method-wrapper '__get__' of function object at 0x000001C78C54F040>,
 '__getattribute__': <method-wrapper '__getattribute__' of function object at 0x000001C78C54F040>,
 '__globals__': {函数对应的全局环境情况，不一一列举了},
 '__gt__': <method-wrapper '__gt__' of function object at 0x000001C78C54F040>,
 '__hash__': 122285281028,
 '__init__': None,
 '__init_subclass__': None,
 '__kwdefaults__': {'prefix': ''},
 '__le__': <method-wrapper '__le__' of function object at 0x000001C78C54F040>,
 '__lt__': <method-wrapper '__lt__' of function object at 0x000001C78C54F040>,
 '__module__': '__main__',
 '__name__': 'myprinter',
 '__ne__': <method-wrapper '__ne__' of function object at 0x000001C78C54F040>,
 '__new__': <built-in method __new__ of type object at 0x00007FFF57678C50>,
 '__qualname__': 'myprinter',
 '__reduce__': <built-in method __reduce__ of function object at 0x000001C78C54F040>,
 '__reduce_ex__': <built-in method __reduce_ex__ of function object at 0x000001C78C54F040>,
 '__repr__': '<function myprinter at 0x000001C78C54F040>',
 '__setattr__': <method-wrapper '__setattr__' of function object at 0x000001C78C54F040>,
 '__sizeof__': 120,
 '__str__': '<function myprinter at 0x000001C78C54F040>',
 '__subclasshook__': NotImplemented}
```

我们可以看到里面的一些关键属性：

- `__name__`：函数名字。
- `__qualname__`：函数的合法名称
  - 比如在`class A`中定义一个函数`f`，那么`A.f.__name__`是`f`，而`A.f.__qualname__`是`A.f`
- `__doc__`：函数注释文本
- `__annotations__`：函数参数注释信息
  - 一般开发时候注释信息都是参数名以及对应的数据类型，因此有了这个就可以对函数的入参进行合法校验。当然，明显也利好一些IoC机制的底层开发的需求。
  - 返回值对应的数据类型，可以在`return`这个key下找
- `__defaults__`：位置参数/非强制关键字参数的默认值的tuple
- `__kwdefaults__`：强制关键字参数的默认值的dict
- `__module__`：函数所属的模块
- `__code__`：函数所包含的代码段对象

除了通过`dir`的方式获取这些关键属性之外，通过`inspect`库的`getmembers`函数也可以实现类似的效果。对于`inspect`库的用法，可以参考[官方文档](https://docs.python.org/3/library/inspect.html)。

## 参数数据结构类型信息

在上述的`__annotations__`属性中，我们能够提取到标注的参数数据结构类型。对于`str`、`int`这种一般型数据就直接标注对应的类型；而对于一些泛型则需要标注为`typing`，比如说`typing.Dict`、`typing.Any`等等。

针对`typing`的用法，可以参考[官方文档](https://docs.python.org/3/library/typing.html)。不过本文计划进一步探索`typing`对象的相关信息。

我们用一段代码就能粗略对`typing`的各类对象信息看个明白：

```python
print('typing.Dict:')
dtype = typing.Dict[str, typing.Union[
    typing.List[int],
    typing.Tuple[bool, str],
    typing.Callable[[float, int], typing.NoReturn]
]]
pprint.pprint(dtype.__dict__)
print('typing.Union:')
utype = dtype.__dict__['__args__'][1]
pprint.pprint(utype.__dict__)
print('typing.List:')
ltype = utype.__dict__['__args__'][0]
pprint.pprint(ltype.__dict__)
print('typing.Tuple:')
ttype = utype.__dict__['__args__'][1]
pprint.pprint(ttype.__dict__)
print('typing.Callable:')
ftype = utype.__dict__['__args__'][2]
pprint.pprint(ftype.__dict__)
print('typing.NoReturn:')
norettype = ftype.__dict__['__args__'][-1]
print(norettype._name)
print(isinstance(norettype, typing._SpecialForm))
```

输出结果：

```text
typing.Dict:
{'__args__': (<class 'str'>,
              typing.Union[typing.List[int], typing.Tuple[bool, str], typing.Callable[[float, int], typing.NoReturn]]),
 '__origin__': <class 'dict'>,
 '__parameters__': (),
 '__slots__': None,
 '_inst': False,
 '_name': 'Dict'}
typing.Union:
{'__args__': (typing.List[int],
              typing.Tuple[bool, str],
              typing.Callable[[float, int], typing.NoReturn]),
 '__module__': 'typing',
 '__origin__': typing.Union,
 '__parameters__': (),
 '__slots__': None,
 '_inst': True,
 '_name': None}
typing.List:
{'__args__': (<class 'int'>,),
 '__origin__': <class 'list'>,
 '__parameters__': (),
 '__slots__': None,
 '_inst': False,
 '_name': 'List'}
typing.Tuple:
{'__args__': (<class 'bool'>, <class 'str'>),
 '__origin__': <class 'tuple'>,
 '__parameters__': (),
 '__slots__': None,
 '_inst': False,
 '_name': 'Tuple'}
typing.Callable:
{'__args__': (<class 'float'>, <class 'int'>, typing.NoReturn),
 '__origin__': <class 'collections.abc.Callable'>,
 '__parameters__': (),
 '__slots__': None,
 '_inst': True,
 '_name': 'Callable'}
typing.NoReturn:
NoReturn
True
```

对于一些容器类型的对象，通过`__dict__['__args__']`就能够获得里面的数据类型标注，从而对容器对象合法性进行检查。对于一些隶属于`typing._SpecialForm`的对象，比如`Any`、`NoReturn`等，可以通过`_name`属性来判断具体是哪个。

## 函数体对象的信息

`code`对象（函数的函数体）的信息，从上面的属性导出情况可知，我们可以通过`__code__`来获取函数的函数体对象。

通过`dir`或者`inspect`等方式，可以导出`code`对象的属性：

```python
codeobj = myprinter.__code__
pprint.pprint(objdict(codeobj))
```

打印结果是：

```text
{'__class__': <class 'code'>,
 '__delattr__': <method-wrapper '__delattr__' of code object at 0x0000012FB44A2500>,
 '__dir__': [忽略],
 '__doc__': 'code(argcount, posonlyargcount, kwonlyargcount, nlocals, '
            'stacksize,\n'
            '      flags, codestring, constants, names, varnames, filename, '
            'name,\n'
            '      firstlineno, lnotab[, freevars[, cellvars]])\n'
            '\n'
            'Create a code object.  Not for the faint of heart.',
 '__eq__': <method-wrapper '__eq__' of code object at 0x0000012FB44A2500>,
 '__format__': <built-in method __format__ of code object at 0x0000012FB44A2500>,
 '__ge__': <method-wrapper '__ge__' of code object at 0x0000012FB44A2500>,
 '__getattribute__': <method-wrapper '__getattribute__' of code object at 0x0000012FB44A2500>,
 '__gt__': <method-wrapper '__gt__' of code object at 0x0000012FB44A2500>,
 '__hash__': -7836529936335626281,
 '__init__': None,
 '__init_subclass__': None,
 '__le__': <method-wrapper '__le__' of code object at 0x0000012FB44A2500>,
 '__lt__': <method-wrapper '__lt__' of code object at 0x0000012FB44A2500>,
 '__ne__': <method-wrapper '__ne__' of code object at 0x0000012FB44A2500>,
 '__new__': <built-in method __new__ of type object at 0x00007FFF5766F870>,
 '__reduce__': <built-in method __reduce__ of code object at 0x0000012FB44A2500>,
 '__reduce_ex__': <built-in method __reduce_ex__ of code object at 0x0000012FB44A2500>,
 '__repr__': '<code object myprinter at 0x0000012FB44A2500, file '
             '"H:\\Projects\\Python\\playground\\datastruct\\functionobj.py", '
             'line 12>',
 '__setattr__': <method-wrapper '__setattr__' of code object at 0x0000012FB44A2500>,
 '__sizeof__': 176,
 '__str__': '<code object myprinter at 0x0000012FB44A2500, file '
            '"H:\\Projects\\Python\\playground\\datastruct\\functionobj.py", '
            'line 12>',
 '__subclasshook__': NotImplemented,
 'co_argcount': 2,
 'co_cellvars': (),
 'co_code': b't\x00|\x02\x83\x01|\x00\x17\x00|\x01\x17\x00}\x03t\x01|\x03'
            b'd\x01d\x02\x8d\x02\x01\x00d\x03|\x03f\x02S\x00',
 'co_consts': ('hello world', '', ('end',), True),
 'co_filename': 'H:\\Projects\\Python\\playground\\datastruct\\functionobj.py',
 'co_firstlineno': 12,
 'co_flags': 67,
 'co_freevars': (),
 'co_kwonlyargcount': 1,
 'co_lnotab': b'\x00\x02\x10\x01\x0c\x01',
 'co_name': 'myprinter',
 'co_names': ('str', 'print'),
 'co_nlocals': 4,
 'co_posonlyargcount': 1,
 'co_stacksize': 4,
 'co_varnames': ('s', 'e', 'prefix', 'msg'),
 'replace': <code object myprinter at 0x0000012FB44CAA80, file "H:\Projects\Python\playground\datastruct\functionobj.py", line 12>}
```

其中一些关键属性如下（同样在[inspect的文档](https://docs.python.org/3/library/inspect.html)中能查到）：

- `co_argcount`：参数个数（不包括强制关键字参数，以及带星号的参数）
- `co_filename`: 所属文件
- `co_firstlineno`：第一行行号
- `co_kwonlyargcount`：强制关键字参数个数
- `co_name`：函数体的名字
- `co_varnames`：参数与变量的名字的tuple
