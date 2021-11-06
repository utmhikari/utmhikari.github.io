---
title: 【Medium Python】第四话：类属性和实例属性是怎样的关系？
date: 2021/11/06 18:34:13
categories:
- Medium Python
tags:
- python
- 源码分析
- descriptor
- 类
- property
---

## 前言

提到编程不得不提到面向对象，一个说烂了的话题，几十年来一直都有人在争论面向对象的好坏。从宏观角度来说，一个庞大的程序本质是对业务中实体集合以及其中的关系的模拟，虽然解决实体的关系问题，用面向过程、组合等方式去体现比较方便，但要解决实体概念的抽象，就需要面向对象的编程基础。因此，面向对象在编程中是非常重要的一部分思想，不能随随便便被否定或者忽略。

​
面向对象的灵魂在于对类（class）概念的剖析，而python中也有对类的支持，虽然不像其它静态语言有比较强的约束，但如果想将代码组织成面向对象式的话也是完全满足的。在平常python的交流以及面试的过程中，也会涉及到许多关于类的问题，比如最常见的就是阐述类与实例的关系。要理解类与实例的关系，从类属性和实例属性切入是为最直观的。因此，今天这篇文章就来讲讲python里类属性和实例属性的二三事。
​

## 在类和实例中访问属性

首先上一段测试代码：

<!-- more -->

```python
def print_seg(msg):
    print('\n'.join(['=' * 40, str(msg), '=' * 40 ]))


class HeadmasterDescriptor:
    headmaster: str = 'Dumbledore'

    def __get__(self, obj, cls):
        return '<HeadmasterDescriptor %s>' % self.headmaster

    def __set__(self, obj, value):
        print('<HeadmasterDescriptor> set new headmaster: %s' % value)
        self.headmaster = str(value)


class Student:
    headmaster = HeadmasterDescriptor()
    students = set()
    teacher = 'Snape'

    def __init__(self, name: str, gender: str, age: int):
        assert gender in ['male', 'female']
        self.name = name
        self.age = age
        self.gender = gender

        # add to students
        self.students.add(name)

    def __del__(self):
        print('<Student> remove student %s' % self.name)
        self.students.remove(self.name)


def main():
    # ============================== test #1 start ==================================
    student_1 = Student(name='conan', gender='male', age=18)
    student_2 = Student(name='saki', gender='female', age=15)
    print_seg('test #1 start')

    # students
    print('[student-1] students: %s' % student_1.students)
    print('[student-2] students: %s' % student_2.students)
    print('[Student] students: %s' % Student.students)

    # dir
    print('[student-1] dir: %s' % dir(student_1))
    print('[Student] dir: %s' % dir(student_1))

    # instance attributes
    print('[student-1] name: %s' % student_1.name)
    print('[student-2] gender: %s' % student_2.gender)
    print('[student-2] age: %s' % getattr(student_2, 'age'))

    # headmaster
    print('[student-1] old headmaster: %s' % getattr(student_1, 'headmaster'))
    print('[student-2] old headmaster: %s' % student_2.headmaster)
    print('[Student] new headmaster: %s' % Student.headmaster)
    print('%s, %s' % (id(student_2.headmaster), id(Student.headmaster)))
    student_1.headmaster = 'Alan Tam'
    print('[student-1] new headmaster: %s' % student_1.headmaster)
    print('[student-2] new headmaster: %s' % student_2.headmaster)
    print('[Student] new headmaster: %s' % getattr(Student, 'headmaster'))

    # remove student
    del student_1
    print('[student-2] students: %s' % student_2.students)
    print('[Student] students: %s' % Student.students)

    # set teacher
    print('[student-2] teacher: %s' % student_2.teacher)
    print('[Student] teacher: %s' % Student.teacher)
    student_2.teacher = 'Jodie'
    print('[student-2] teacher: %s' % student_2.teacher)
    print('[Student] teacher: %s' % Student.teacher)

    print_seg('test#1 end')
    # ============================== test #1 end ==================================


if __name__ == '__main__':
    main()

```

这一段代码构造了这样的场景：

- 首先创建两个学生，创建的过程中将学生名加入到集合`students`
- 用`dir`打印学生实例`student-1`及学生类`Student`的属性&方法，再通过点或者`getattr`的方式访问实例属性
- 更换`headmaster`
- 删除`student_1`
- 更换`teacher`

我们看到打印的结果是这样：

```text
========================================
test #1 start
========================================
[student-1] students: {'saki', 'conan'}
[student-2] students: {'saki', 'conan'}
[Student] students: {'saki', 'conan'}
[student-1] dir: ['__class__', '__del__', '__delattr__', '__dict__', '__dir__', '__doc__', '__eq__', '__format__', '__ge__', '__getattribute__', '__gt__', '__hash__', '__init__', '__init_subclass__', '__le__', '__lt__', '__module__', '__ne__', '__new__', '__reduce__', '__reduce_ex__', '__repr__', '__setattr__', '__sizeof__', '__str__', '__subclasshook__', '__weakref__', 'age', 'gender', 'headmaster', 'name', 'students', 'teacher']
[Student] dir: ['__class__', '__del__', '__delattr__', '__dict__', '__dir__', '__doc__', '__eq__', '__format__', '__ge__', '__getattribute__', '__gt__', '__hash__', '__init__', '__init_subclass__', '__le__', '__lt__', '__module__', '__ne__', '__new__', '__reduce__', '__reduce_ex__', '__repr__', '__setattr__', '__sizeof__', '__str__', '__subclasshook__', '__weakref__', 'age', 'gender', 'headmaster', 'name', 'students', 'teacher']
[student-1] name: conan
[student-2] gender: female
[student-2] age: 15
[student-1] old headmaster: <HeadmasterDescriptor Dumbledore>
[student-2] old headmaster: <HeadmasterDescriptor Dumbledore>
[Student] new headmaster: <HeadmasterDescriptor Dumbledore>
1999801558000, 1999801558000
<HeadmasterDescriptor> set new headmaster: Alan Tam
[student-1] new headmaster: <HeadmasterDescriptor Alan Tam>
[student-2] new headmaster: <HeadmasterDescriptor Alan Tam>
[Student] new headmaster: <HeadmasterDescriptor Alan Tam>
<Student> remove student conan
[student-2] students: {'saki'}
[Student] students: {'saki'}
[student-2] teacher: Snape
[Student] teacher: Snape
[student-2] teacher: Jodie
[Student] teacher: Snape
========================================
test#1 end
========================================
<Student> remove student saki
```

可以看到：

- 创建两个学生的时候，`student`的名字被加入到了类属性`students`中。不论在类还是还是在实例去访问`students`，都能得到相同的结果。
- 通过`getattr`或者带点的方法，能够正常访问到类或者实例的属性。
- 更换`headmaster`。
  - `headmaster`是一个带`getter`跟`setter`的`descriptor`
  - 所谓`descriptor`，可以简单理解为一个支持根据不同访问方式做出特定行为的特殊属性。我们对`headmaster`执行`get`操作，获得的是`__get__`方法的返回结果，当对`headmaster`赋新值时，如果发现了带`__set__`的`descriptor`，就会触发这个逻辑，改变类属性`headmaster`这个`descriptor`里面维护的值。
  - 否则，属性在类里没有被定义成为`descriptor`，且在实例里面有定义的话，修改操作只会改实例本身维护的属性值，就像下面的`teacher`一样。
- 删除`student_1`，触发了类定义的`__del__`函数，将`student_1`的名字从`students`里面移除
- `student_2`更换`teacher`，只更换了自己的，类属性里面还是默认原来的。

从表现上来看，类相对于实例更多是起到一个模板的作用，每一个实例类似于`fork`了一个类，然后在`__init__`中添加属于自己的属性。如果一个实例要访问某个属性，这个属性在`__init__`里面没有定义到的话，就会下一步从自己的类里寻找属性。如果还找不到，就得从父类里找了，就到了（多重）继承相关的话题。

所以，为什么会有这样的呈现呢？接下来我们深入源码，一探究竟。
获取类的属性，其字节码为`LOAD_ATTR`。经过一番深入，最终会落实到`_PyObject_GenericGetAttrWithDict`

```c
// object.c

PyObject *
_PyObject_GenericGetAttrWithDict(PyObject *obj, PyObject *name,
                                 PyObject *dict, int suppress)
{
    /* Make sure the logic of _PyObject_GetMethod is in sync with
       this method.

       When suppress=1, this function suppress AttributeError.
    */

    PyTypeObject *tp = Py_TYPE(obj);
    PyObject *descr = NULL;
    PyObject *res = NULL;
    descrgetfunc f;
    Py_ssize_t dictoffset;
    PyObject **dictptr;

    if (!PyUnicode_Check(name)){
        PyErr_Format(PyExc_TypeError,
                     "attribute name must be string, not '%.200s'",
                     Py_TYPE(name)->tp_name);
        return NULL;
    }
    Py_INCREF(name);

    if (tp->tp_dict == NULL) {
        if (PyType_Ready(tp) < 0)
            goto done;
    }

    descr = _PyType_Lookup(tp, name);

    f = NULL;
    if (descr != NULL) {
        Py_INCREF(descr);
        f = Py_TYPE(descr)->tp_descr_get;
        if (f != NULL && PyDescr_IsData(descr)) {
            res = f(descr, obj, (PyObject *)Py_TYPE(obj));
            if (res == NULL && suppress &&
                    PyErr_ExceptionMatches(PyExc_AttributeError)) {
                PyErr_Clear();
            }
            goto done;
        }
    }

    if (dict == NULL) {
        /* Inline _PyObject_GetDictPtr */
        dictoffset = tp->tp_dictoffset;
        if (dictoffset != 0) {
            if (dictoffset < 0) {
                Py_ssize_t tsize = Py_SIZE(obj);
                if (tsize < 0) {
                    tsize = -tsize;
                }
                size_t size = _PyObject_VAR_SIZE(tp, tsize);
                _PyObject_ASSERT(obj, size <= PY_SSIZE_T_MAX);

                dictoffset += (Py_ssize_t)size;
                _PyObject_ASSERT(obj, dictoffset > 0);
                _PyObject_ASSERT(obj, dictoffset % SIZEOF_VOID_P == 0);
            }
            dictptr = (PyObject **) ((char *)obj + dictoffset);
            dict = *dictptr;
        }
    }
    if (dict != NULL) {
        Py_INCREF(dict);
        res = PyDict_GetItemWithError(dict, name);
        if (res != NULL) {
            Py_INCREF(res);
            Py_DECREF(dict);
            goto done;
        }
        else {
            Py_DECREF(dict);
            if (PyErr_Occurred()) {
                if (suppress && PyErr_ExceptionMatches(PyExc_AttributeError)) {
                    PyErr_Clear();
                }
                else {
                    goto done;
                }
            }
        }
    }

    if (f != NULL) {
        res = f(descr, obj, (PyObject *)Py_TYPE(obj));
        if (res == NULL && suppress &&
                PyErr_ExceptionMatches(PyExc_AttributeError)) {
            PyErr_Clear();
        }
        goto done;
    }

    if (descr != NULL) {
        res = descr;
        descr = NULL;
        goto done;
    }

    if (!suppress) {
        PyErr_Format(PyExc_AttributeError,
                     "'%.50s' object has no attribute '%U'",
                     tp->tp_name, name);
    }
  done:
    Py_XDECREF(descr);
    Py_DECREF(name);
    return res;
}
```

从这段代码以及其中的部分函数调用定义，可以知悉，获取属性有以下的优先级：

- 首先在类继承链搜索是否有对应名字的`descriptor`。如果有带`__get__`的`descriptor`，且包含`__set__`的话（`PyDescr_IsData`的判断），优先选择这个`descriptor`
- 其次是在实例的`__dict__`中寻找属性
  - 有兴趣的同学可以在上面的测试代码中给实例和类加上`__dict__`，看一下输出结果
- 然后如果这个`descriptor`是有带`__get__`的，就通过这个`descriptor`的`__get__`方法获取这个属性值
- 最后如果没有带`__get__`的，那可能这只是个普通实例，不算严格意义上的`descriptor`（比如`Student.teacher`），就返回对应的值即可

类的继承链，可以通过类的`__mro__`属性获得到，是用C3线性化算法得到的。有兴趣的同学可以了解背后的原理以及代码实现。python的多重继承，就是基于这一套机制。
由先前代码的例子我们可以看到带`__get__`、`__set__`的`descriptor`确实从类、实例里都获得的是同一个`descriptor`。
​
同样，当设置属性时，最终会调用`_PyObject_GenericSetAttrWithDict`（`object.c`里，这里不放源码了，有兴趣自行查阅）。其中的优先级是：

- 在继承链查找属性有带`__set__`的`descriptor`，直接调用`descriptor.__set__`
- 如果没有，就在实例的`__dict__`里直接设置属性

​

## 在类方法中访问实例属性

在类定义里面我们通常会加各式各样的函数（方法），在方法的定义里面也会大量访问`self`的属性。但我们要知道，python是一个动态语言，函数定义里的`self`，并不一定只能是这个类的实例。不仅传进子类实例是可以的，而是只要满足函数里面属性的访问的类实例，都行。

如果有学过golang，或是了解过组合、ecs的概念的同学都会一下明白——如果一个东西，它皮肤是土黄色无花纹，体型大，跑得快，牙齿锋利，肉食，有金黄色的头发，那么它应当是个雄狮。就算世界上可能有其它动物也满足这些条件，但如果我们只关心这些特征属性，那就可以一视同仁。类方法也是这样，如果没有对实例类型的约束，只有对实例属性的约束，那么只要满足这些属性的实例，都可以成为类方法的参数。我们看一个例子：

```python
class Lion:
    def __init__(self, name: str, age: int):
        self.name = name
        self.age = age


class Student:
    def __init__(self, name: str, gender: str, age: int):
        assert gender in ['male', 'female']
        self.name = name
        self.gender = gender
        self.age = age

    def output(self):
        print('class: %s, name: %s, age: %s' % (
            self.__class__.__name__,
            self.name,
            self.age
        ))


if __name__ == '__main__':
    s = Student(name='haha', gender='male', age=18)
    s.output()
    Student.output(s)
    Student.output(Lion(name='simba', age=5))
```

重点在于最后一句：`Student.output(Lion(name='simba', age=5))`——这句话是成立的，从打印的结果来看也没有报错。而同时，`s.output()`和`Student.output(s)`则呈现了相同的效果。

我们打印`s.output()`以及`Student.output(s)`的`opcode`结果（上面代码稍微改了点内容，比如实例`s`变成了`student`），可以发现其中的不同：

```text
 29          26 LOAD_FAST                0 (student)
             28 LOAD_METHOD              2 (output)
             30 CALL_METHOD              0
             32 POP_TOP

 30          34 LOAD_GLOBAL              0 (Student)
             36 LOAD_METHOD              2 (output)
             38 LOAD_FAST                0 (student)
             40 CALL_METHOD              1
             42 POP_TOP
```

调用`student.output`时，直接`LOAD_METHOD`后就`call`了；而调用`Student.output`时，还要`load`一个参数`student`（当然，也可以是其它实例）再`call`。`opcode`的呈现和源代码是一致的。

我们首先看`LOAD_METHOD`对应的内容

```c
case TARGET(LOAD_METHOD): {
    /* Designed to work in tandem with CALL_METHOD. */
    PyObject *name = GETITEM(names, oparg);
    PyObject *obj = TOP();
    PyObject *meth = NULL;

    int meth_found = _PyObject_GetMethod(obj, name, &meth);

    if (meth == NULL) {
        /* Most likely attribute wasn't found. */
        goto error;
    }

    if (meth_found) {
        /* We can bypass temporary bound method object.
                   meth is unbound method and obj is self.

                   meth | self | arg1 | ... | argN
                 */
        SET_TOP(meth);
        PUSH(obj);  // self
    }
    else {
        /* meth is not an unbound method (but a regular attr, or
                   something was returned by a descriptor protocol).  Set
                   the second element of the stack to NULL, to signal
                   CALL_METHOD that it's not a method call.

                   NULL | meth | arg1 | ... | argN
                */
        SET_TOP(NULL);
        Py_DECREF(obj);
        PUSH(meth);
    }
    DISPATCH();
}
```

`LOAD_METHOD`会落实到`_PyObject_GetMethod`方法：

```c
int
_PyObject_GetMethod(PyObject *obj, PyObject *name, PyObject **method)
{
    PyTypeObject *tp = Py_TYPE(obj);
    PyObject *descr;
    descrgetfunc f = NULL;
    PyObject **dictptr, *dict;
    PyObject *attr;
    int meth_found = 0;

    assert(*method == NULL);

    if (Py_TYPE(obj)->tp_getattro != PyObject_GenericGetAttr
            || !PyUnicode_Check(name)) {
        *method = PyObject_GetAttr(obj, name);
        return 0;
    }

    if (tp->tp_dict == NULL && PyType_Ready(tp) < 0)
        return 0;

    descr = _PyType_Lookup(tp, name);
    if (descr != NULL) {
        Py_INCREF(descr);
        if (_PyType_HasFeature(Py_TYPE(descr), Py_TPFLAGS_METHOD_DESCRIPTOR)) {
            meth_found = 1;
        } else {
            f = Py_TYPE(descr)->tp_descr_get;
            if (f != NULL && PyDescr_IsData(descr)) {
                *method = f(descr, obj, (PyObject *)Py_TYPE(obj));
                Py_DECREF(descr);
                return 0;
            }
        }
    }

    dictptr = _PyObject_GetDictPtr(obj);
    if (dictptr != NULL && (dict = *dictptr) != NULL) {
        Py_INCREF(dict);
        attr = PyDict_GetItemWithError(dict, name);
        if (attr != NULL) {
            Py_INCREF(attr);
            *method = attr;
            Py_DECREF(dict);
            Py_XDECREF(descr);
            return 0;
        }
        else {
            Py_DECREF(dict);
            if (PyErr_Occurred()) {
                Py_XDECREF(descr);
                return 0;
            }
        }
    }

    if (meth_found) {
        *method = descr;
        return 1;
    }

    if (f != NULL) {
        *method = f(descr, obj, (PyObject *)Py_TYPE(obj));
        Py_DECREF(descr);
        return 0;
    }

    if (descr != NULL) {
        *method = descr;
        return 0;
    }

    PyErr_Format(PyExc_AttributeError,
                 "'%.50s' object has no attribute '%U'",
                 tp->tp_name, name);
    return 0;
}
```

`_PyObject_GetMethod`包含了多处判断。对于`student.output`和`Student.output`，走到了不同的分支：

- 当调用`student.output`时，通过`_PyType_Lookup(tp, name)`找到了`output`函数（`PyFunction_Type`）的`descriptor`，调用`tp_descr_get`对应的方法
  - 最终回到`LOAD_METHOD`，走到`if (meth_found)`对应的分支
  - 栈顶是`student`实例，然后是`output`方法
- 当调用`Student.output`时，由于`Student`是一个`type`，`Py_TYPE(obj)->tp_getattro`是`PyType_Type`里面的`type_getattro`而不是`PyObject_GenericGetAttr`，且`name`合法，所以直接用`PyObject_GetAttr(obj, name)`找到了对应的`output`方法
  - 最终回到`LOAD_METHOD`，走到`if (meth_found)`的`else`对应的分支
  - 栈顶是`output`方法，然后是`NULL`

`LOAD_METHOD`之后就是`CALL_METHOD`，这个时候我们要记得`Student.output`是有传参的，因此还会额外`push`一个`student`到栈上。之后，我们再来看`CALL_METHOD`：

```c
case TARGET(CALL_METHOD): {
    /* Designed to work in tamdem with LOAD_METHOD. */
    PyObject **sp, *res, *meth;

    sp = stack_pointer;

    meth = PEEK(oparg + 2);
    if (meth == NULL) {
        /* `meth` is NULL when LOAD_METHOD thinks that it's not
                   a method call.

                   Stack layout:

                       ... | NULL | callable | arg1 | ... | argN
                                                            ^- TOP()
                                               ^- (-oparg)
                                    ^- (-oparg-1)
                             ^- (-oparg-2)

                   `callable` will be POPed by call_function.
                   NULL will will be POPed manually later.
                */
        res = call_function(tstate, &sp, oparg, NULL);
        stack_pointer = sp;
        (void)POP(); /* POP the NULL. */
    }
    else {
        /* This is a method call.  Stack layout:

                     ... | method | self | arg1 | ... | argN
                                                        ^- TOP()
                                           ^- (-oparg)
                                    ^- (-oparg-1)
                           ^- (-oparg-2)

                  `self` and `method` will be POPed by call_function.
                  We'll be passing `oparg + 1` to call_function, to
                  make it accept the `self` as a first argument.
                */
        res = call_function(tstate, &sp, oparg + 1, NULL);
        stack_pointer = sp;
    }

    PUSH(res);
    if (res == NULL)
        goto error;
    DISPATCH();
}
```

在`CALL_METHOD`中会对栈做检查。如果不出意外，栈上自顶向下应该是这样的结构（看下`LOAD_METHOD`跟`CALL_METHOD`的注释就能明白）：

- `student.output`：参数N~参数1（假使有的话），`student`实例，`output`方法
- `Student.output`：参数N+1~参数2（假使有的话），`student`实例（参数1），`output`方法，`NULL`

最终都会调用`call_function`，而两者最终的效果都是`Student.output(student, *args, **kwargs)`了。
因此我们可以看到，假使在`Student.output`传参另外一个类的实例，如果调用到相关属性的话，最终还是会在另外一个类的实例里面调用`PyObject_GenericGetAttrWithDict`。这个方法是通用的，并约束为单一的类，所以这才能解释`Student.output(Lion(name='simba', age=5))`为什么成立（当然，现实编程不建议这样写哦！有其它更好的workaround提升代码可读性）。

## descriptor属性的应用：property

在上两个小节当中，我们多次提到了`descriptor`这个概念。在平时的python编程中，我们基本上很难接触到`descriptor`，但在python的内部实现中，`descriptor`是非常核心的一部分，可以说是一种为了适配python的类属性访问接口而生的数据结构。因此，每个修习python的同学，都有必要了解这个概念。

就说一些常见的内置类属性定义，像是`property`、`classmethod`、`staticmethod`，虽然它们以装饰器的形式呈现在我们的程序里，但它们的实质，都是`descriptor`。这也是`descriptor`的魔力所在。

本文以`property`为例解析下`descriptor`的应用。首先来看测试代码：

```python
import pprint


class Human:
    def __init__(self, first_name='', last_name=''):
        self.__first_name = first_name
        self.__last_name = last_name

    @property
    def first_name(self):
        return self.__first_name

    @first_name.setter
    def first_name(self, value):
        print('[%s] change first name to %s' % (id(self), value))
        self.__first_name = str(value)

    @property
    def last_name(self):
        return self.__last_name

    @last_name.setter
    def last_name(self, value):
        print('[%s] change last name to %s' % (id(self), value))
        self.__last_name = str(value)

    @property
    def full_name(self):
        return '%s %s' % (self.first_name, self.last_name)


def main():
    h = Human(first_name='James', last_name='Bond')
    h1 = Human(first_name='Anatoli', last_name='Todorov')
    print('first name: %s' % h.first_name)
    print('last name: %s' % h.last_name)
    print('full name: %s' % h.full_name)
    h.first_name = 'Jiss'
    h1.last_name = 'Toledo'
    print('[h] first name: %s' % h.first_name)
    print('[h] full name: %s' % h.full_name)
    print('[h1] last name: %s' % h1.last_name)
    print('[h1] full name: %s' % h1.full_name)
    print('[Human] first name: %s' % Human.first_name)
    print('[Human] last name: %s' % Human.last_name)
    print('[Human] full name: %s' % Human.full_name)
    print('[h] dict: %s' % h.__dict__)
    print('[h1] dict: %s' % h1.__dict__)
    print('[Human] dict: %s' % pprint.pformat(Human.__dict__))


if __name__ == '__main__':
    main()

```

打印出来的结果是：

```text
first name: James
last name: Bond
full name: James Bond
[1661162208128] change first name to Jiss
[1661162208032] change last name to Toledo
[h] first name: Jiss
[h] full name: Jiss Bond
[h1] last name: Toledo
[h1] full name: Anatoli Toledo
[Human] first name: <property object at 0x00000182C4FB7B80>
[Human] last name: <property object at 0x00000182C4FB7BD0>
[Human] full name: <property object at 0x00000182C4F9E220>
[h] dict: {'_Human__first_name': 'Jiss', '_Human__last_name': 'Bond'}
[h1] dict: {'_Human__first_name': 'Anatoli', '_Human__last_name': 'Toledo'}
[Human] dict: mappingproxy({'__dict__': <attribute '__dict__' of 'Human' objects>,
              '__doc__': None,
              '__init__': <function Human.__init__ at 0x00000182C4FB3B80>,
              '__module__': '__main__',
              '__weakref__': <attribute '__weakref__' of 'Human' objects>,
              'first_name': <property object at 0x00000182C4FB7B80>,
              'full_name': <property object at 0x00000182C4F9E220>,
              'last_name': <property object at 0x00000182C4FB7BD0>})
```

`property`常用于一些私有变量定义的规范化，这里我们从实例的`__dict__`也可以额外看到带两个下划线前缀的私有变量在代码编译时就已经被偷偷地改名了（有兴趣的同学可以了解下`_Py_Mangle`）。在类里面，所有`property`相关的属性都是`property object`；而在实例里面，所有`property`相关的属性相互独立，并且是特定的值。

`property`是如何实现这个效果的？我们需要进入源码一探究竟。

首先我们看`property`对应的类型定义`PyProperty_Type`

```c
PyTypeObject PyProperty_Type = {
    PyVarObject_HEAD_INIT(&PyType_Type, 0)
    "property",                                 /* tp_name */
    sizeof(propertyobject),                     /* tp_basicsize */
    0,                                          /* tp_itemsize */
    /* methods */
    property_dealloc,                           /* tp_dealloc */
    0,                                          /* tp_vectorcall_offset */
    0,                                          /* tp_getattr */
    0,                                          /* tp_setattr */
    0,                                          /* tp_as_async */
    0,                                          /* tp_repr */
    0,                                          /* tp_as_number */
    0,                                          /* tp_as_sequence */
    0,                                          /* tp_as_mapping */
    0,                                          /* tp_hash */
    0,                                          /* tp_call */
    0,                                          /* tp_str */
    PyObject_GenericGetAttr,                    /* tp_getattro */
    0,                                          /* tp_setattro */
    0,                                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC |
        Py_TPFLAGS_BASETYPE,                    /* tp_flags */
    property_init__doc__,                       /* tp_doc */
    property_traverse,                          /* tp_traverse */
    (inquiry)property_clear,                    /* tp_clear */
    0,                                          /* tp_richcompare */
    0,                                          /* tp_weaklistoffset */
    0,                                          /* tp_iter */
    0,                                          /* tp_iternext */
    property_methods,                           /* tp_methods */
    property_members,                           /* tp_members */
    property_getsetlist,                        /* tp_getset */
    0,                                          /* tp_base */
    0,                                          /* tp_dict */
    property_descr_get,                         /* tp_descr_get */
    property_descr_set,                         /* tp_descr_set */
    0,                                          /* tp_dictoffset */
    property_init,                              /* tp_init */
    PyType_GenericAlloc,                        /* tp_alloc */
    PyType_GenericNew,                          /* tp_new */
    PyObject_GC_Del,                            /* tp_free */
};
```

从定义中我们可以看到，`PyProperty_Type`的`tp_descr_get`和`tp_descr_set`都有对应的回调函数，因此任何一个`property`的实例都可以当作是一个`descriptor`

我们创建一个`property`实例的时候，是采用装饰器的写法，解析出来就是类似于`property(function)`的形式。因此，我们需要再看一下`property`实例创建的过程。

`property`本身是一个`type object`，创建实例的时候，是按照`property(function)`的写法来解析，这就相当于把`property`当成一个函数来看待。我们可以首先看下`type object`的类`PyType_Type`的定义：

```c
PyTypeObject PyType_Type = {
    PyVarObject_HEAD_INIT(&PyType_Type, 0)
    "type",                                     /* tp_name */
    sizeof(PyHeapTypeObject),                   /* tp_basicsize */
    sizeof(PyMemberDef),                        /* tp_itemsize */
    (destructor)type_dealloc,                   /* tp_dealloc */
    offsetof(PyTypeObject, tp_vectorcall),      /* tp_vectorcall_offset */
    0,                                          /* tp_getattr */
    0,                                          /* tp_setattr */
    0,                                          /* tp_as_async */
    (reprfunc)type_repr,                        /* tp_repr */
    0,                                          /* tp_as_number */
    0,                                          /* tp_as_sequence */
    0,                                          /* tp_as_mapping */
    0,                                          /* tp_hash */
    (ternaryfunc)type_call,                     /* tp_call */
    0,                                          /* tp_str */
    (getattrofunc)type_getattro,                /* tp_getattro */
    (setattrofunc)type_setattro,                /* tp_setattro */
    0,                                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC |
    Py_TPFLAGS_BASETYPE | Py_TPFLAGS_TYPE_SUBCLASS |
    Py_TPFLAGS_HAVE_VECTORCALL,                 /* tp_flags */
    type_doc,                                   /* tp_doc */
    (traverseproc)type_traverse,                /* tp_traverse */
    (inquiry)type_clear,                        /* tp_clear */
    0,                                          /* tp_richcompare */
    offsetof(PyTypeObject, tp_weaklist),        /* tp_weaklistoffset */
    0,                                          /* tp_iter */
    0,                                          /* tp_iternext */
    type_methods,                               /* tp_methods */
    type_members,                               /* tp_members */
    type_getsets,                               /* tp_getset */
    0,                                          /* tp_base */
    0,                                          /* tp_dict */
    0,                                          /* tp_descr_get */
    0,                                          /* tp_descr_set */
    offsetof(PyTypeObject, tp_dict),            /* tp_dictoffset */
    type_init,                                  /* tp_init */
    0,                                          /* tp_alloc */
    type_new,                                   /* tp_new */
    PyObject_GC_Del,                            /* tp_free */
    (inquiry)type_is_gc,                        /* tp_is_gc */
};
```

易知，如果把`type object`当作函数（严格意义上讲，叫做可调用的，`callable`）看待，会触发`tp_call`对应的`type_call`函数。`type_call`函数这里就不列出来了，因为只有两步是最为关键的：

- `obj = type->tp_new(type, args, kwds)`
- `res = type->tp_init(obj, args, kwds)`

也就是说，要创建`property`实例，需要找到`property`的`tp_new`对应的函数先弄一个空的实例，然后再找`tp_init`对应的函数初始化实例。由`PyProperty_Type`的定义可知，`property`的`tp_new`对应的是`PyType_GenericNew`，简单分配了内存空间；而`tp_init`则对应`property_init`，`property_init`实质的实现是`property_init_impl`，因此我们直接看`property_init_impl`的定义。

```c
static int
property_init_impl(propertyobject *self, PyObject *fget, PyObject *fset,
                   PyObject *fdel, PyObject *doc)
/*[clinic end generated code: output=01a960742b692b57 input=dfb5dbbffc6932d5]*/
{
    if (fget == Py_None)
        fget = NULL;
    if (fset == Py_None)
        fset = NULL;
    if (fdel == Py_None)
        fdel = NULL;

    Py_XINCREF(fget);
    Py_XINCREF(fset);
    Py_XINCREF(fdel);
    Py_XINCREF(doc);

    Py_XSETREF(self->prop_get, fget);
    Py_XSETREF(self->prop_set, fset);
    Py_XSETREF(self->prop_del, fdel);
    Py_XSETREF(self->prop_doc, doc);
    self->getter_doc = 0;

    /* if no docstring given and the getter has one, use that one */
    if ((doc == NULL || doc == Py_None) && fget != NULL) {
        _Py_IDENTIFIER(__doc__);
        PyObject *get_doc;
        int rc = _PyObject_LookupAttrId(fget, &PyId___doc__, &get_doc);
        if (rc <= 0) {
            return rc;
        }
        if (Py_IS_TYPE(self, &PyProperty_Type)) {
            Py_XSETREF(self->prop_doc, get_doc);
        }
        else {
            /* If this is a property subclass, put __doc__
               in dict of the subclass instance instead,
               otherwise it gets shadowed by __doc__ in the
               class's dict. */
            int err = _PyObject_SetAttrId((PyObject *)self, &PyId___doc__, get_doc);
            Py_DECREF(get_doc);
            if (err < 0)
                return -1;
        }
        self->getter_doc = 1;
    }

    return 0;
}
```

`property`实例初始化，传入的参数是`fget`、`fset`、`fdel`、`doc`，从`property_init_impl`中我们易知，四个参数最终会放到`prop_get`、`prop_set`、`prop_del`、`prop_doc`中。一般我们用`property`装饰器包裹的函数，就对应了`fget`。
​
在先前的“访问属性”中，我们了解到如果一个类实例访问属性，第一优先级是判断继承链上是不是有名字对应了一个`data-descriptor`（同时包含`__get__`与`__set__`）。从上面的例子我们最终会发现在类里面定义了`first_name`之类的`property object`，而`property object`的类型`PyProperty_Type`就是同时拥有`tp_descr_get`跟`tp_descr_set`，可以当作一个`data-descriptor`，因此在`_PyObject_GenericGetAttrWithDict`中，会直接走到`f(descr, obj, (PyObject *)Py_TYPE(obj))`这一个逻辑来返回结果。转换一下函数里面涉及的变量名，就变成了`tp_descr_get(property实例, 类实例, 类)`

`property`的`tp_descr_get`对应的是`property_descr_get`，我们看下其中的定义：

```c
static PyObject *
property_descr_get(PyObject *self, PyObject *obj, PyObject *type)
{
    if (obj == NULL || obj == Py_None) {
        Py_INCREF(self);
        return self;
    }

    propertyobject *gs = (propertyobject *)self;
    if (gs->prop_get == NULL) {
        PyErr_SetString(PyExc_AttributeError, "unreadable attribute");
        return NULL;
    }

    return PyObject_CallOneArg(gs->prop_get, obj);
}
```

我们看到，`getter`的逻辑最终会调用`property object`的`prop_get`，传参`obj`。显然，这个`prop_get`就是我们用`property`包裹的`fget`函数，而`obj`就是类实例，我们的`fget`函数第一个参数就是`self`。那么显然，我们就直接通过`fget`获取了类实例对应的属性。
​
至此我们也可以发现，在上面的python测试代码中，`h.first_name`和`Human.first_name.fget(h)`，两者就是相同的表达。再引申一下，假使有个类的实例叫做`fakehuman`，它包含一个属性叫做`_Human__first_name`（记得上面说的，双下划线的变量会被改名），那么`Human.first_name.fget(fakehuman)`这个表达式也是通过的！

`property`的`setter`也是一样的套路，最终会落实到`property_descr_set`

```c
static int
property_descr_set(PyObject *self, PyObject *obj, PyObject *value)
{
    propertyobject *gs = (propertyobject *)self;
    PyObject *func, *res;

    if (value == NULL)
        func = gs->prop_del;
    else
        func = gs->prop_set;
    if (func == NULL) {
        PyErr_SetString(PyExc_AttributeError,
                        value == NULL ?
                        "can't delete attribute" :
                "can't set attribute");
        return -1;
    }
    if (value == NULL)
        res = PyObject_CallOneArg(func, obj);
    else
        res = PyObject_CallFunctionObjArgs(func, obj, value, NULL);
    if (res == NULL)
        return -1;
    Py_DECREF(res);
    return 0;
}
```

从`property_descr_set`里可以看出，当`value`为`NULL`（不是传进python的`None`哈），就会调用`prop_del`对应的`deleter`（删除属性用`del`，对应`opcode`为`DELETE_ATTR`，实质就是设置`attr`为`NULL`）；当`value`为非`null`的时候，就会调用`prop_set`对应的`setter`。这样，一个属性`setter`跟`deleter`的的需求也就轻而易举地被满足了。
​

从`property`的实现可以看到，`descriptor`相当于在属性本身和用户访问之间起到了一层桥梁的作用，是非常灵活巧妙的构思。而`classmethod`、`staticmethod`，本质上也是`non-data-descriptor`（不带`setter`），有兴趣的同学也可以深入研究。

## 总结

本文通过类/实例属性之间的联系，对python的类和实例之间的关系做了剖析，并引申了python内部实现中重要的一个概念——`descriptor`。在三个月前，笔者甚至根本不知道`descriptor`是什么东西，而经过了这一段时间的学习，也对python类/实例属性实现机制有了全新的理解。希望大家阅读此文，也能有所收获。
