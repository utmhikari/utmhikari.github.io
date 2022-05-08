---
title: 【Hard Python】【第五章-字符串】1、unicode，py3的字符串实现
date: 2022/05/08 14:36:30
categories:
- Hard Python
tags:
- python
- 字符串
- str
- unicode
- utf8
---

`python`的字符串实质到底是什么类型的数据，这个可是困扰着很多编程者的话题。在`python2`我们已经被中文编码相关的问题折磨的不轻，那到了`python3`之后为什么又解决了这个问题呢？今天这篇文章就带大家详细剖析`python3`的字符串实现。

我们首先看一段代码：

```python
def test_str_basic():
    s = '123456789'
    print(type(s))
```

这段代码打印了一个字符串对象的类型，其结果为`<class 'str'>`。`str`类型从哪里来？从C源码中我们可以搜索到，其来源于`unicodeobject.c`的`PyUnicode_Type`

<!-- more -->

```c
// unicodeobject.c
PyTypeObject PyUnicode_Type = {
    PyVarObject_HEAD_INIT(&PyType_Type, 0)
    "str",                        /* tp_name */
    sizeof(PyUnicodeObject),      /* tp_basicsize */
    0,                            /* tp_itemsize */
    /* Slots */
    (destructor)unicode_dealloc,  /* tp_dealloc */
    0,                            /* tp_vectorcall_offset */
    0,                            /* tp_getattr */
    0,                            /* tp_setattr */
    0,                            /* tp_as_async */
    unicode_repr,                 /* tp_repr */
    &unicode_as_number,           /* tp_as_number */
    &unicode_as_sequence,         /* tp_as_sequence */
    &unicode_as_mapping,          /* tp_as_mapping */
    (hashfunc) unicode_hash,      /* tp_hash*/
    0,                            /* tp_call*/
    (reprfunc) unicode_str,       /* tp_str */
    PyObject_GenericGetAttr,      /* tp_getattro */
    0,                            /* tp_setattro */
    0,                            /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE |
        Py_TPFLAGS_UNICODE_SUBCLASS |
        _Py_TPFLAGS_MATCH_SELF, /* tp_flags */
    unicode_doc,                  /* tp_doc */
    0,                            /* tp_traverse */
    0,                            /* tp_clear */
    PyUnicode_RichCompare,        /* tp_richcompare */
    0,                            /* tp_weaklistoffset */
    unicode_iter,                 /* tp_iter */
    0,                            /* tp_iternext */
    unicode_methods,              /* tp_methods */
    0,                            /* tp_members */
    0,                            /* tp_getset */
    &PyBaseObject_Type,           /* tp_base */
    0,                            /* tp_dict */
    0,                            /* tp_descr_get */
    0,                            /* tp_descr_set */
    0,                            /* tp_dictoffset */
    0,                            /* tp_init */
    0,                            /* tp_alloc */
    unicode_new,                  /* tp_new */
    PyObject_Del,                 /* tp_free */
};
```

对应地，其大小为`PyUnicodeObject`所占的大小。`PyUnicodeObject`可表示的数据结构如下：

```c
// unicodeobject.h
typedef struct {
    PyCompactUnicodeObject _base;
    union {
        void *any;
        Py_UCS1 *latin1;
        Py_UCS2 *ucs2;
        Py_UCS4 *ucs4;
    } data;                     /* Canonical, smallest-form Unicode buffer */
} PyUnicodeObject;


typedef struct {
    PyASCIIObject _base;
    Py_ssize_t utf8_length;     /* Number of bytes in utf8, excluding the
                                 * terminating \0. */
    char *utf8;                 /* UTF-8 representation (null-terminated) */
    Py_ssize_t wstr_length;     /* Number of code points in wstr, possible
                                 * surrogates count as two code points. */
} PyCompactUnicodeObject;


typedef struct {
    PyObject_HEAD
    Py_ssize_t length;          /* Number of code points in the string */
    Py_hash_t hash;             /* Hash value; -1 if not set */
    struct {
        unsigned int interned:2;
        unsigned int kind:3;
        unsigned int compact:1;
        unsigned int ascii:1;
        unsigned int ready:1;
        unsigned int :24;
    } state;
    wchar_t *wstr;              /* wchar_t representation (null-terminated) */
} PyASCIIObject;
```

其中，`PyUnicodeObject`、`PyCompactUnicodeObject`、`PyASCIIObject`分别对应三种不同的字符串类型，它们有以下区别：

- `PyASCIIObject`：通过`PyUnicode_New`生成的只包含`ASCII`字符的字符串，字符数据会紧随结构体排列
- `PyCompactUnicodeObject`：通过`PyUnicode_New`生成的包含非`ASCII`字符的字符串，字符数据会紧随结构体排列
- `PyUnicodeObject`：通过`PyUnicode_FromUnicode`创建

其中`PyUnicode_FromUnicode`是已经过时的方法，因此我们常见的`unicode`对象是以`PyASCIIObject`、`PyCompactUnicodeObject`的形式存在的，也就是说现在我们日常创建的字符串对象，其数据会紧随结构体排列。

`python`的`unicode`实现是对标标准`unicode`规范的，因此要深入了解其中原理，我们需要预备一些关于`unicode`的知识，比如：

- [unicode tutorial](http://www.unifoundry.com/unicode-tutorial.html)
- [unicode wiki](https://zh.wikipedia.org/zh-hans/Unicode)
- [彻底弄懂unicode编码](https://www.cnblogs.com/crazylqy/p/10184291.html)

`unicode`本身存在的意义是将世界上任意一个字符（包括`emoji`）映射到一个特定的数字，这个数字被称为`code point`。`unicode`的`code point`是分组的，每组`65536`个，称作为一个个`plane`。每个`unicode`字符用4个字节表示，但如果需要进行二进制编码的话，比如存储文件或是网络传输，每个字符都使用4个字节往往会有冗余，因此需要一个比较效率的二进制编码方式，比如：`utf8`、`utf16`。

`utf8`编码是最常见的编码之一，其长度可变，但针对不同`unicode`的`code point`值，会编码成不同长度的形式，比如`ASCII`支持的英文在`utf8`编码里只占1个字节，但汉字可能就是3个字节。在python中，当我们需要把字符串编码成`utf8`的二进制形式时，就需要`string.encode('utf-8')`的调用，反之假设我们从一个`socket`接收到`utf8`编码的数据，需要解码成字符串时，就需要`bytestring.decode('utf-8')`对字符串进行解码。

言归正传，现在我们回到对`PyASCIIObject`、`PyCompactUnicodeObject`数据结构的研究当中。首先我们看`PyASCIIObject`，它有以下几个部分：

- `length`：字符串的长度，按`code point`个数计算
- `hash`：字符串的hash编码
- `state`：字符串状态，用一个完整4字节存储
   - `interned`（2）：是否被短字符串缓存，以及是否永久缓存
   - `kind`（3）：字符串的类型
      - 0：`wide-char`宽字符类型
      - 1：`1byte`，全部字符都可用`8bits`无符号表示
      - 2：`2byte`，全部字符都可用`16bits`无符号表示
      - 4：`4byte`，全部字符都可用`32bits`无符号表示
   - `compact`（1）：字符串数据是否紧凑于结构体排列
      - 先前提到`PyASCIIObject`、`PyCompactUnicodeObject`都是紧凑排列
   - `ascii`（1）：是否只有`ascii`字符
      - 先前`kind=1`的时候由于是`unsigned`，因此可以表示除`ascii`外到200多的字符
   - `ready`（1）：是否数据已准备完成
      - 紧凑排列数据，或者非紧凑排列但数据指针已经填好字符串数据，都算`read`y
   - 24位`padding`
- `wstr`：`wide-char`的字符串表示

`PyASCIIObject`用来表示`ASCII`字符，而含有非`ASCII`字符的字符串则用`PyCompactUnicodeObject`表示，其包含以下内容：

- `_base`：`PyASCIIObject`的实例
- `utf8_length`：除了`\0`之外，`utf8`的字符串表示的比特数
- `utf8`：`utf8`的字符串表示
- `wstr_length`：wide-char字符串表示里`code point`的个数

而字符串的真实数据则放到了`PyUnicodeObject`的`data`当中，以一个`union`的形式表示不同长度表示的字符串

接下来我们通过一个例子来展示`unicode`字符串是如何被创建的。我们的代码是字母+汉字+数字：

```python
s = "abc哈咯123"
```

当这段代码被打入到解释器中，被词法分析器分析时，就会调用字符串创建的逻辑`unicode_decode_utf8`，将`const char`类型的原生字符转化为`PyUnicodeObject`

```c
// unicodeobject.c
static PyObject *
unicode_decode_utf8(const char *s, Py_ssize_t size,
                    _Py_error_handler error_handler, const char *errors,
                    Py_ssize_t *consumed)
{
    if (size == 0) {
        if (consumed)
            *consumed = 0;
        _Py_RETURN_UNICODE_EMPTY();
    }

    /* ASCII is equivalent to the first 128 ordinals in Unicode. */
    if (size == 1 && (unsigned char)s[0] < 128) {
        if (consumed) {
            *consumed = 1;
        }
        return get_latin1_char((unsigned char)s[0]);
    }

    const char *starts = s;
    const char *end = s + size;

    // fast path: try ASCII string.
    PyObject *u = PyUnicode_New(size, 127);
    if (u == NULL) {
        return NULL;
    }
    s += ascii_decode(s, end, PyUnicode_1BYTE_DATA(u));
    if (s == end) {
        return u;
    }

    // Use _PyUnicodeWriter after fast path is failed.
    _PyUnicodeWriter writer;
    _PyUnicodeWriter_InitWithBuffer(&writer, u);
    writer.pos = s - starts;

    Py_ssize_t startinpos, endinpos;
    const char *errmsg = "";
    PyObject *error_handler_obj = NULL;
    PyObject *exc = NULL;

    while (s < end) {
        Py_UCS4 ch;
        int kind = writer.kind;

        if (kind == PyUnicode_1BYTE_KIND) {
            if (PyUnicode_IS_ASCII(writer.buffer))
                ch = asciilib_utf8_decode(&s, end, writer.data, &writer.pos);
            else
                ch = ucs1lib_utf8_decode(&s, end, writer.data, &writer.pos);
        } else if (kind == PyUnicode_2BYTE_KIND) {
            ch = ucs2lib_utf8_decode(&s, end, writer.data, &writer.pos);
        } else {
            assert(kind == PyUnicode_4BYTE_KIND);
            ch = ucs4lib_utf8_decode(&s, end, writer.data, &writer.pos);
        }

        switch (ch) {
        case 0:
            if (s == end || consumed)
                goto End;
            errmsg = "unexpected end of data";
            startinpos = s - starts;
            endinpos = end - starts;
            break;
        case 1:
            errmsg = "invalid start byte";
            startinpos = s - starts;
            endinpos = startinpos + 1;
            break;
        case 2:
            if (consumed && (unsigned char)s[0] == 0xED && end - s == 2
                && (unsigned char)s[1] >= 0xA0 && (unsigned char)s[1] <= 0xBF)
            {
                /* Truncated surrogate code in range D800-DFFF */
                goto End;
            }
            /* fall through */
        case 3:
        case 4:
            errmsg = "invalid continuation byte";
            startinpos = s - starts;
            endinpos = startinpos + ch - 1;
            break;
        default:
            if (_PyUnicodeWriter_WriteCharInline(&writer, ch) < 0)
                goto onError;
            continue;
        }

        // case 1、3、4的逻辑，会获取不同类型的error_handler，这里先忽略
    }

End:
    if (consumed)
        *consumed = s - starts;

    Py_XDECREF(error_handler_obj);
    Py_XDECREF(exc);
    return _PyUnicodeWriter_Finish(&writer);

onError:
    Py_XDECREF(error_handler_obj);
    Py_XDECREF(exc);
    _PyUnicodeWriter_Dealloc(&writer);
    return NULL;
}
```

`unicode_decode_utf8`做了以下几件事情：

- 当`size`为1并且第一个字符值小于128时，通过`get_latin1_char`方法获取`unicode`实例
- 采用`PyUnicode_New`初始化`unicode`实例并预设最大字符值为127，然后先尝试用`ascii_decode`将原生字符串转换为一个`ascii`的`unicode`实例
   - 如果成功就`return`了
   - 如果没成功，`s`会停在第一个非`ascii`字符的前面
      - 在上面的例子里，`s`也就表示`"哈咯123"`
- 以先前的`unicode`实例为`buffer`，初始化`PyUnicodeWriter`实例处理非`ASCII`字符串，循环处理剩余的字符，写入到`buffer`
   - `PyUnicodeWriter`实例默认的`kind`为`PyUnicode_1BYTE_KIND`。一般第一个字符会走到`asciilib_utf8_decode`逻辑，这个逻辑如果发现字符越界，会返回字符实际的`code point`值
- 发现第一个字符越界不能用`ASCII`表示，调用`_PyUnicodeWriter_WriteCharInline`逻辑写入字符
   - 调用`_PyUnicodeWriter_Prepare`逻辑，其中会根据第一个字符的值大小决定`writer`写入的字符类型`kind`
      - 汉字`"哈"`对应`code point`值为`27014`，即`\u54c8`。因此`writer`将`kind`调整到`PyUnicode_2BYTE_KIND`，以适配汉字`"哈"`的写入
   - 调用`PyUnicode_WRITE`，写入字符`"哈"`到`buffer`
- `writer.kind`为`PyUnicode_2BYTE_KIND`，下一个循环之后，调用`ucs2lib_utf8_decode`方法
   - 由于汉字基本是`PyUnicode_2BYTE_KIND`，通过`ucs2lib_utf8_decode`方法，就能把后面所有的字符都进行处理
- 调用`_PyUnicodeWriter_Finish`，生成最终的`unicode`实例
   - 调用`resize_compact`，重新调整`unicode`实例数据

通过以上的操作，一个`unicode`字符串实例就生成了。
