---
title: 【Hard Python】【第五章-字符串】2、re，正则表达式源码详解
date: 2022/05/14 20:50:18
categories:
- Hard Python
tags:
- python
- re
- 正则表达式
- pattern
- 字符串
---


正则表达式是文本处理中的重要部分，通过匹配特定的正则表达式，能够很方便地编写提取特定文本的代码。在`python`中，同样也已经拥有了正则表达式库`re`，为各位开发者提供了正则表达式的支持。

在`python`官方文档中，已经对正则表达式模块接口、词法和用法做了详细的介绍：

- [`re`——正则表达式操作](https://docs.python.org/zh-cn/3/library/re.html)
- [正则表达式HOWTO](https://docs.python.org/zh-cn/3/howto/regex.html#regex-howto)

正则表达式常见的用法如下：

```python
import re


def test_pattern():
    pat = re.compile('[0-9]{2,3}')
    print(pat.match('a'))
    print(pat.match('1'))
    print(pat.match('111'))


def test_matches():
    s = '123abc456def789xyz007ddc'
    pat = re.compile('([0-9]+)([a-z]+([0-9]+))')
    for match in pat.finditer(s):
        print(match.groups())


if __name__ == '__main__':
    test_pattern()
    test_matches()
```

`test_pattern`中，`compile`了一个只匹配2~3个数字字符的正则对象，`test_matches`中，则匹配了数字+小写字母+数字的正则对象，并且用括号分了三个组。两个函数打印出来的结果是：

```text
None
None
<re.Match object; span=(0, 3), match='111'>
('123', 'abc456', '456')
('789', 'xyz007', '007')
```

接下来我们就深入其中，看下源码怎么实现的。

<!-- more -->

首先我们就这两个语句来看：

```python
pat = re.compile('[0-9]{2,3}')
pat.match('111')
```

`re.compile`对一个正则表达式解析后，会生成正则模式`Pattern`对象，`Pattern`对象可以用于匹配一个特定的字符串。因此我们可以通过`re.compile`的逻辑切入，先探究`Pattern`对象的实现：

```python
# re.py
def compile(pattern, flags=0):
    return _compile(pattern, flags)


def _compile(pattern, flags):
    # 尝试先从LRU获取
    p = sre_compile.compile(pattern, flags)
    # 更新LRU
    return p


# sre_compile.py
def compile(p, flags=0):
    if isstring(p):
        pattern = p
        p = sre_parse.parse(p, flags)  # 解析字符串
    else:
        pattern = None
    code = _code(p, flags)
    if flags & SRE_FLAG_DEBUG:
        print()
        dis(code)
    # map in either direction
    groupindex = p.state.groupdict
    indexgroup = [None] * p.state.groups
    for k, i in groupindex.items():
        indexgroup[i] = k
    return _sre.compile(
        pattern, flags | p.state.flags, code,
        p.state.groups-1,
        groupindex, tuple(indexgroup)
        )
```

正则`Pattern`的生成，最终走到了`sre_compile.py`中的`compile`函数，主要是两个步骤：

- 通过`sre_parse.parse`解析正则表达式字符串
- 通过`_code`方法生成解析结果的字节码，然后通过`_sre.compile`生成最终的`Pattern`对象

首先我们来看`parse`解析逻辑，其代码实现如下

```python
# sre_parse.py
def parse(str, flags=0, state=None):
    source = Tokenizer(str)
    if state is None:
        state = State()
    state.flags = flags
    state.str = str
    try:
        p = _parse_sub(source, state, flags & SRE_FLAG_VERBOSE, 0)
    except Verbose:
        state = State()
        state.flags = flags | SRE_FLAG_VERBOSE
        state.str = str
        source.seek(0)
        p = _parse_sub(source, state, True, 0)
    p.state.flags = fix_flags(str, p.state.flags)
    if source.next is not None:
        assert source.next == ")"
        raise source.error("unbalanced parenthesis")
    if flags & SRE_FLAG_DEBUG:
        p.dump()
    return p


def _parse_sub(source, state, verbose, nested):
    items = []
    itemsappend = items.append
    sourcematch = source.match
    start = source.tell()
    while True:
        itemsappend(_parse(source, state, verbose, nested + 1,
                           not nested and not items))
        if not sourcematch("|"):
            break
    if len(items) == 1:
        return items[0]
    subpattern = SubPattern(state)
    while True:
        prefix = None
        for item in items:
            if not item:
                break
            if prefix is None:
                prefix = item[0]
            elif item[0] != prefix:
                break
        else:
            for item in items:
                del item[0]
            subpattern.append(prefix)
            continue # check next one
        break
    set = []
    for item in items:
        if len(item) != 1:
            break
        op, av = item[0]
        if op is LITERAL:
            set.append((op, av))
        elif op is IN and av[0][0] is not NEGATE:
            set.extend(av)
        else:
            break
    else:
        subpattern.append((IN, _uniq(set)))
        return subpattern
    subpattern.append((BRANCH, (None, items)))
    return subpattern
```

大致捋一下流程：

- 初始化`Tokenizer`：提供了访问、检索字符串当前以及后续的词法单元`token`的一系列方法，供`parser`运行过程中调用
- 初始化`State`：用于记录解析过程中的状态，检测一些解析的异常情况，主要是记录跟组`group`有关的信息
  - `group`在正则表达式中，相当于小括号之间的内容
- 调用`_parse_sub`，传入`Tokenizer`跟`State`实例，解析正则表达式

在`_parse_sub`里，则是这样的流程：

- 不断调用`_parse`解析出以`|`符号分隔的一个个`SubPattern`实例
   - `SubPattern`可以认为是一个单位`Pattern`，不同`SubPattern`之间相互嵌套，形成树的结构
- 如果只出一个`SubPattern`实例，直接返回，否则进行后续逻辑
- 如果每个`SubPattern`实例都共享相同匹配前缀，就把相同前缀提取出来
- 如果每个`SubPattern`实例都能以字符集表示，就整合成一个字符集
- 将多个`SubPattern`实例组合为一个`BRANCH`分支匹配`SubPattern`，并返回

`_parse`函数是解析正则的主体逻辑，具体代码可以在`sre_parse.py`中查阅。以刚才给定的`'[0-9]{2,3}'`为例子，会进行如下的步骤：

- 匹配到`[`符号，进入`[`的分支
   - 首先判断是否有`^`符号（`negate`），即表示`“非xxx字符”`的含义，实际是没有
   - 进入字符集取值循环，首先取到字符`0`
   - 取完了之后判断是否有范围匹配模式`-`，发现有，进入`-`的分支
   - 在`-`的分支里，取到字符`9`
   - 之后取到`]`，退出字符集取值循环
   - 后处理：对字符集取值取交集，如果有`negate`就取非
   - 退出`]`的分支，当前`SubPattern`实例包含了模式：`(IN, [(RANGE, (48, 57))])`
- 在`REPEAT_CHARS`匹配到`{`符号，进入`{`的分支
   - `REPEAT_CHARS`表示重复字符，即`*+?{`
   - 不断提取字符，解析`x,y`样式的字符串，确定重复次数范围
   - 解析到`}`，退出 `{` 的分支
   - `wrap`前面的`SubPattern`，得到新的`SubPattern`模式：`(MAX_REPEAT, (2, 3, [(IN, [(RANGE, (48, 57))])]))`
- 取不到下一个字符，退出循环

可以看到整个`_parse`逻辑是一个状态机的形式，匹配到不同的词法单元`token`，在不同分支的词法分析状态下，相同的`token`会呈现不同的涵义。因此整块代码呈现起来，就成了`if-else`的大杂烩

如果是包含多个`group`的情况，就还要走更多的的分支逻辑。我们用一个例子来看：`'(?<=ab)([^\\si-w]+([125]+?))'`，它的逻辑是这样走的：

- 匹配到`(`符号，进入`(`的分支
   - 发现第一个符号是`?`，表明这一段是非获取匹配
      - 非获取匹配表示，整个模式最终能匹配到的各个字符串组里，不会包括非获取匹配的括号的部分
      - 判断下一个符号是不是`<`，如果是则为反向预查匹配
      - 解析非获取匹配的`SubPattern`实例
      - 判断对比符号是`=`还是 `!` ，决定这组`SubPattern`要么是`ASSERT`，要么是`ASSERT_NOT`
      - 得到`SubPattern`实例`(ASSERT, (-1, [(LITERAL, 97), (LITERAL, 98)]))`，继续下一轮循环
- 又匹配到`(`符号，再次进入`(`的分支
   - 第一个符号不是`?`，进入后续逻辑，调用`state.opengroup`，自增`groups`计数
   - 解析后面的`pattern`，先得到`[^\\si-w]+`对应的一段：`(MAX_REPEAT, (1, MAXREPEAT, [(IN, [(NEGATE, None), (CATEGORY, CATEGORY_SPACE), (RANGE, (105, 119))])]))`
   - 再次匹配到`(`符号，又进入一次`(`的分支
      - 得到`[125]+?`对应的一段`SubPattern`：`(MIN_REPEAT, (1, MAXREPEAT, [(IN, [(LITERAL, 49), (LITERAL, 50), (LITERAL, 53)])]))`
        可以注意到非贪婪匹配实际用`MIN_REPEAT`语义表示
      - 匹配到`)`符号，退出
      - 调用`state.closegroup`，在`state`中记录`[125]+?`对应的匹配宽度到组`2：(1, 4294967295)`
      - 添加一个`SUBPATTERN`类型的`SubPattern`实例，里面封装`group`计数号、解析到的真实`SubPattern`实例以及其它信息
      - 匹配 `)`，退出`(`的分支
   - 匹配到`)`，退出`(`的分支
   - 调用`state.closegroup`，在`state`中记录`[^\\si-w]+([125]+?)`对应的匹配宽度到组`1：(2, MAXREPEAT)`
- 父`subpattern`遍历名下所有`SubPattern`实例，如果发现由`SUBPATTERN`类型且真实`SubPattern`实例为非捕获组（`non-capturing`，即形似`(?:)`的形式），就提取真实的`SubPattern`实例出来替换当前`SUBPATTERN`类型的实例

这样整个`parse`的部分就结束了，最终我们获取到：

- `subpattern`
   - 根`subpattern`，也就是整个正则表达式
   - `SUBPATTERN`实例1：`[^\\si-w]+([125]+?)`
   - `SUBPATTERN`实例2：`[125]+?`
- `state`
   - `groups`计数为3（下一个`group`的`id`），需要再-1，即实际只有2个`group`
   - 1、2号下标宽度：`(2, MAXREPEAT)`、`(1, 4294967295)`
- `code`：`subpattern`被编译出来的字节码序列，用以进行实际的匹配操作

接下来就是`_sre.compile`的逻辑了，这里先暂不列举了，有兴趣可以在`_sre.c`中看到，主要作用就是把所有信息集合在一起封装成为单独的一个`re.Pattern`实例

```c
// _sre.c
static PyType_Spec pattern_spec = {
    .name = "re.Pattern",
    .basicsize = sizeof(PatternObject),
    .itemsize = sizeof(SRE_CODE),
    .flags = (Py_TPFLAGS_DEFAULT | Py_TPFLAGS_IMMUTABLETYPE |
              Py_TPFLAGS_DISALLOW_INSTANTIATION | Py_TPFLAGS_HAVE_GC),
    .slots = pattern_slots,
};
```

封装完了之后的`Pattern`实例，就可以用来匹配字符串了。我们以`'(?<=ab)([^\\si-w]+([125]+?))'`这个`Pattern`实例为例，来匹配字符串`'  abcde1233  gabh5455'`，找到所有匹配的组合

我们可以用`finditer`方法，寻找所有匹配的`Match`实例，`finditer`方法的实现在`_sre_SRE_Pattern_finditer_impl`中：

```c
static PyObject *
_sre_SRE_Pattern_finditer_impl(PatternObject *self, PyTypeObject *cls,
                               PyObject *string, Py_ssize_t pos,
                               Py_ssize_t endpos)
{
    _sremodulestate *module_state = get_sre_module_state_by_class(cls);
    PyObject* scanner;
    PyObject* search;
    PyObject* iterator;
    scanner = pattern_scanner(module_state, self, string, pos, endpos);
    if (!scanner)
        return NULL;
    search = PyObject_GetAttrString(scanner, "search");
    Py_DECREF(scanner);
    if (!search)
        return NULL;
    iterator = PyCallIter_New(search, Py_None);
    Py_DECREF(search);

    return iterator;
}
```

`finditer`创建了一个`ScannerObject`用于对整个字符串的扫描，会不断调用`ScannerObject`的`search`方法取搜索匹配但不重叠的子串。`ScannerObject`和`Pattern`的`search`方法原理是一样的，只不过`Pattern.search`是一次性的，而`ScannerObject`的`search`在进行一轮之后会更新自身内部的状态，调整匹配起始位置，以方便下一轮匹配

`ScannerObject`的`search`方法是如下的实现：

```c
static PyObject *
_sre_SRE_Scanner_search_impl(ScannerObject *self, PyTypeObject *cls)
{
    _sremodulestate *module_state = get_sre_module_state_by_class(cls);
    SRE_STATE* state = &self->state;
    PyObject* match;
    Py_ssize_t status;
    if (state->start == NULL)
        Py_RETURN_NONE;
    state_reset(state);
    state->ptr = state->start;
    status = sre_search(state, PatternObject_GetCode(self->pattern));
    if (PyErr_Occurred())
        return NULL;
    match = pattern_new_match(module_state, (PatternObject*) self->pattern,
                              state, status);
    if (status == 0)
        state->start = NULL;
    else {
        state->must_advance = (state->ptr == state->start);
        state->start = state->ptr;
    }
    return match;
}
```

其步骤如下：

- 重置内部维护的状态
- 调用`sre_search`，匹配一个符合正则的子串
- 调用`pattern_new_match`，生成一个`Match`实例

`sre_search`最终会调用`SRE(match)`进行匹配操作，如果第一个字符起头匹配失败的话，`sre_search`还会继续以后面的字符起头开始匹配，直到匹配到为止

```c
// sre_lib.h
LOCAL(Py_ssize_t)
SRE(search)(SRE_STATE* state, SRE_CODE* pattern)
{
    // 省略上面
		/* general case */
        assert(ptr <= end);
        TRACE(("|%p|%p|SEARCH\n", pattern, ptr));
        state->start = state->ptr = ptr;
        status = SRE(match)(state, pattern, 1);  // status为0表示匹配失败，1表示成功
        state->must_advance = 0;
        while (status == 0 && ptr < end) {
            ptr++;
            RESET_CAPTURE_GROUP();
            TRACE(("|%p|%p|SEARCH\n", pattern, ptr));
            state->start = state->ptr = ptr;
            status = SRE(match)(state, pattern, 0);
        }
    return status
}
```

`SRE(match)`会根据`pattern`编译出来的`code`字节码里面的内容，根据不同的字节码，走到对应的分支逻辑再逐字匹配，类似于`python`虚拟机解析`python`字节码的操作：

```c
LOCAL(Py_ssize_t)
SRE(match)(SRE_STATE* state, const SRE_CODE* pattern, int toplevel)
{
    // 大循环
	for (;;) {
        ++sigcount;
        switch (*ctx->pattern++) {  // 根据不同的操作符，执行不同的匹配判断
        case SRE_OP_MARK:
            TRACE(("|%p|%p|MARK %d\n", ctx->pattern,
                   ctx->ptr, ctx->pattern[0]));
            i = ctx->pattern[0];
            if (i & 1)
                state->lastindex = i/2 + 1;
            if (i > state->lastmark) {
                Py_ssize_t j = state->lastmark + 1;
                while (j < i)
                    state->mark[j++] = NULL;
                state->lastmark = i;
            }
            state->mark[i] = ctx->ptr;
            ctx->pattern++;
            break;

        case SRE_OP_LITERAL:
            TRACE(("|%p|%p|LITERAL %d\n", ctx->pattern,
                   ctx->ptr, *ctx->pattern));
            if (ctx->ptr >= end || (SRE_CODE) ctx->ptr[0] != ctx->pattern[0])
                RETURN_FAILURE;
            ctx->pattern++;
            ctx->ptr++;
            break;
        }
    }
}
```

在字符串`'  abcde1233  gabh5455'`中，当起始字符`ptr`指向第一个`c`的时候，将会有一次成功的匹配，其步骤如下：

- 遇到`SRE_OP_ASSERT`以及`SRE_OP_LITERAL`字节码，反向匹配前面的`ab`子串
- 遇到`SRE_OP_MARK`字节码，记录第一个`group`的起始位置，`MARK`的参数为`0`
- 遇到`SRE_OP_REPEAT_ONE`字节码，匹配`[^\\si-w]+`模式的最大子串，即为`cde1233`
   - 尝试匹配后面的内容，在`SRE_OP_MARK`分支记录第二个`group`的起始位置，参数为`2`
   - 遇到`SRE_OP_MIN_REPEAT_ONE`，非贪婪匹配`[125]+?`
   - 因为`cde1233`后面的字符是空格，匹配失败，退出一轮匹配
   - 先前匹配最大字串为`cde1233`，因后面模式匹配失败，尾部索引-1，继续匹配
   - 直到子串为`cde1`，非贪婪匹配到`2`，匹配成功
- 连续遇到`SRE_OP_MARK`字节码，记录两个`group`的最终位置，`MARK`的参数分别为`3`和`1`
   - 这样`MARK`里面，`0、1`和`2、3`里面的指向内容，就分别对应了两个`group`的起止位置
- 遇到`SRE_OP_SUCCESS`字节码，表示最终匹配成功

接下来就是通过`pattern_new_match`生成`Match`实例，其实现如下：

```c
static PyObject*
pattern_new_match(_sremodulestate* module_state,
                  PatternObject* pattern,
                  SRE_STATE* state,
                  Py_ssize_t status)
{
    MatchObject* match;
    Py_ssize_t i, j;
    char* base;
    int n;
    if (status > 0) {
        match = PyObject_GC_NewVar(MatchObject,module_state->Match_Type,2*(pattern->groups+1));
        if (!match)
            return NULL;
        Py_INCREF(pattern);
        match->pattern = pattern;
        Py_INCREF(state->string);
        match->string = state->string;
        match->regs = NULL;
        match->groups = pattern->groups+1;
        base = (char*) state->beginning;
        n = state->charsize;
        match->mark[0] = ((char*) state->start - base) / n;
        match->mark[1] = ((char*) state->ptr - base) / n;
        for (i = j = 0; i < pattern->groups; i++, j+=2)
            if (j+1 <= state->lastmark && state->mark[j] && state->mark[j+1]) {
                match->mark[j+2] = ((char*) state->mark[j] - base) / n;
                match->mark[j+3] = ((char*) state->mark[j+1] - base) / n;
            } else
                match->mark[j+2] = match->mark[j+3] = -1; /* undefined */
        match->pos = state->pos;
        match->endpos = state->endpos;
        match->lastindex = state->lastindex;
        PyObject_GC_Track(match);
        return (PyObject*) match;
    } else if (status == 0) {
        Py_RETURN_NONE;
    }
    pattern_error(status);
    return NULL;
}
```

其中最关键的部分是`match->mark`的几段代码，会记录每一个`group`在字符串中的位置。`match->mark`的`0、1`对应的是整个匹配到的字串的起止位置，而后面的`2、3`跟`4、5`就匹配`state->mark`里面的`0、1`跟`2、3`两个`group`的起止位置。生成完`MatchObject`之后，`Scanner`会更新起始指针到匹配子串的末尾，以便进行下一轮的匹配。

当我们获取到一个`MatchObject`的时候，我们可以通过调用`group(i)`取获取每个匹配组匹配到的子串。`group(i)`最终会落到`match_getslice_by_index`方法，会根据传进去的`i`，匹配`match->mark[i]`到`match->mark[i + 1]`的字串。也就是说，`group(0)`就是整一个匹配的字符串`cde12`，而`group(1)`以及`group(2)`就对应着两个小括号的匹配组，分别是`cde12`跟`2`。这样，我们就完成了整一个匹配的过程。

正则表达式的源码就解析到这里。本文对`re`库的“正则字符串->匹配模式->字符串匹配”这一流程涉及的代码做了详细的讲解，希望各位读者通过阅读这篇文章，能够对正则表达式本身的概念以及python正则表达式的实现由更加深入的理解，也希望一些先前对正则表达式有所纠结的朋友，看完这篇文章之后，能够不再感到纠结，从而提升对正则表达式的掌控力！

最后说一句，笔者决定，Hard Python系列，到此画上句号。希望每一位喜欢`python`，并且阅读过这个系列的朋友，能够有所感悟，有所收获！技术永不死，望诸君共勉！

