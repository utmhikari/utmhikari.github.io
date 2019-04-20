---
title: 【Lua杂谈】探索C API，开坑lnodelist
date: 2019/04/20 20:42:51
categories:
- Lua杂谈
tags:
- Lua
- C API
- lnodelist
- 双向链表
- array
---

# 前言

最近一直在探索Lua的C API编程部分，上次实现了一个函数执行时间统计库：[lfunctimer](https://github.com/utmhikari/lfunctimer)，这次就果断写了一个`lnodelist`来玩玩。在这期间，遇到了许多纠结的问题，因此果断做下分享~

测试用例现在贼少= =想要试用的同学可以走`lnodelist`的[Github传送门](https://github.com/utmhikari/lnodelist)，或者`luarocks install lnodelist`，就可以开始干起~

在Lua里，table充当着array以及hashmap两个角色，提供了简单的insert、remove、concat等功能。`lnodelist`则是独立于table之外建立一个崭新的`list/array`数据结构，暂时是一个双向链表。API的需求上，则兼并java的LinkedList跟js的array两种体系，列表如下：

<!-- more -->

```c
static const luaL_Reg lnodelist_f[] = {
  {"new", list_new},  // local l = list.new()
  {"size", list_size},  // list.size(l) or #l
  {"push", list_push},  // list.push(l, val)
  {"pushleft", list_pushleft},  // list.pushleft(l, val)
  {"pop", list_pop},  // list.pop(l) -> last val
  {"popleft", list_popleft},  // list.popleft(l) -> first val
  {"remove", list_remove},  // list.remove(l)
  {"removeleft", list_removeleft},  // list.removeleft(l)
  {"set", list_set},  // list.set(l, idx, val)
  {"get", list_get},  // list.get(l, idx) -> l[idx]
  {"insert", list_insert},  // list.insert(l, idx, val)
  {"delete", list_delete},  // list.delete(l, idx)
  {"reverse", list_reverse},  // list.reverse(l)
  {"clear", list_clear},  // list.clear(l)
  {"extend", list_extend},  // list.extend(l1, l2)
  {"slice", list_slice},  // list.slice(l [, start [, end]]) -> sl
  {"join", list_join},  // list.join(l, sep [,start [, end]])
  {"foreach", list_foreach},  // list.foreach(l, (val, idx) => {})
  {"map", list_map},  // list.map(l, (val, idx) => newVal) -> mapl
  {"some", list_some},  // list.some(l, (val, idx) => boolean)
  {"find", list_find},  // list.find(l, (val, idx) => trueVal)
  {"__len", list_size},  // same as list.size(l)
  {"__gc", list_clear},  // same as list.clear(l)
  {"__tostring", list_tostring},  // print list length and lua registry reference
  {NULL, NULL},
};
```

# 踩坑记录

## 数据结构与元表设计

`lnodelist`本身要实现为一个非lua的自定义的数据结构，在Lua里，这种数据结构属于`userdata`的类型，是一个可以被lua的GC（garbage collection，倒垃圾）机制检测回收的`struct`结构体数据块。从双向链表的设计上来看，初始化的`userdata`可以包含`size`、`*head`以及`*tail`三方面。通过`size`、`*head`以及`*tail`三个信息，我们就可以简单管理一个双向链表。而链表的每个结点内存则需要自己管理，其数据结构包含`type`、`*value`、`*prev`以及`*next`四个信息，分别是结点数据的类型、值跟链表里边上一个、下一个结点的指针。因此，`lnodelist`的`userdata`结构体跟结点结构体定义可以如下：

```c
/* struct of node */
typedef struct l_node {
  int type;
  void *value;
  struct l_node *prev;
  struct l_node *next;
} l_node;

/* struct of list */
typedef struct l_list {
  lua_Integer size;
  struct l_node *head;
  struct l_node *tail;
} l_list;
```

`lnodelist`作为一个用户自定义数据，我们需要通过一个叫元表（metatable）的东西对其基本属性以及在lua运行过程中发生特定事件下的行为进行描述。了解过元数据（metadata）的同学都会知道，它是描述数据的数据，其实元表，也不离其宗。在`lnodelist`的元表中，我们必须得重新定义这个数据树结构被lua标记GC时的行为（事件`__gc`）。

GC（Garbage Collection）行为可以回收数据的内存，但是我们在lua虚拟机定义`lnodelist`的过程中，值定义了刚开始的`userdata`，而后面结点的内存则暂时是一个个自己操作的，并不受lua虚拟机管辖。因此，GC时候，需要注意回收结点内存。

`lnodelist`采用Lua最新版5.3.5的C API编写。相对于某些旧版本（如5.1），其注册lib的方式（luaopen函数里边的逻辑）不一样了。经过一番探究，参考了lua源码某些地方的骚操作，现在的写法可以这样：

```c
LUAMOD_API int luaopen_lnodelist(lua_State *L) {
  luaL_newmetatable(L, LUA_NODELIST);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_setfuncs(L, lnodelist_f, 0);
  return 1;
}
```

而后，每次新建`list`时，注册一下元表即可。

```c
/* push a new empty list on lua stack */
void new_list(lua_State *L) {
  l_list *l = (l_list *)lua_newuserdata(L, sizeof(l_list));
  l->size = 0;
  l->head = NULL;
  l->tail = l->head;
  luaL_setmetatable(L, LUA_NODELIST);
}
```

## 数据存取

在lua中，采用`TValue`表示lua的数据

```c
// lobject.h

/*
** Union of all Lua values
*/
typedef union Value {
  GCObject *gc;    /* collectable objects */
  void *p;         /* light userdata */
  int b;           /* booleans */
  lua_CFunction f; /* light C functions */
  lua_Integer i;   /* integer numbers */
  lua_Number n;    /* float numbers */
} Value;


#define TValuefields	Value value_; int tt_


typedef struct lua_TValue {
  TValuefields;
} TValue;
```

为此，在结点`l_node`中，也同样采用`type`加`value`的形式，表示每一个存到链表的数据。

获取数据的类型可以通过`lua_type`函数获得，根据数据的类型，我们可以做switch跳表去走相应的分支存数据。

值得一提的是，部分数据类型（比如函数、table），在API里我们无法直接获得相应数据结构的struct定义，因此只能通过lua的注册表Registry找到这些数据唯一索引，然后把索引值存在`value`中，这样通过`type`跟`value`就能找到对应的数据了。

数据存储的逻辑如下：

```c
/* assign value to value pointer, may modify type */
void assign_val(lua_State *L, l_node* node, int arg) {
  int type = lua_type(L, arg);
  switch (type) {
    case LUA_TNUMBER:
      if (lua_isinteger(L, arg)) {
        node->value = malloc(sizeof(lua_Integer));
        *(lua_Integer *)node->value = lua_tointeger(L, arg);
        node->type = LUA_TINTEGER;
      } else {
        ...  // lua_Number
      }
      break;
    case LUA_TSTRING:
      ...  // const char*
    case LUA_TBOOLEAN:
      ...  // int (bool)
    case LUA_TNIL:
    case LUA_TNONE:
      ...  // nil
    default:  // store in registry index
      lua_pushvalue(L, arg);
      node->value = malloc(sizeof(int));
      *(int *)node->value = luaL_ref(L, LUA_REGISTRYINDEX);
      node->type = type;
      break;
  }
```

反过来，取数据push到lua栈上的逻辑如下：

```c
/* get value of node and push to lua stack */
void push_val(lua_State *L, l_node *node) {
  switch (node->type) {
    case LUA_TINTEGER:
      lua_pushinteger(L, *(lua_Integer *)(node->value));
      break;
    case LUA_TNUMBER:
      lua_pushnumber(L, *(lua_Number *)(node->value));
      break;
    case LUA_TSTRING:
      lua_pushstring(L, *(const char **)(node->value));
      break;
    case LUA_TBOOLEAN:
      lua_pushstring(L, (int *)node->value ? "true" : "false");
      break;
    case LUA_TNIL:  // nil or none
    case LUA_TNONE:
      lua_pushnil(L);
      break;
    default:  // get from registry index
      lua_rawgeti(L, LUA_REGISTRYINDEX, *(int *)node->value);
      break;
  }
}
```

销毁数据（free）时，特殊的数据结构暂时需要在lua注册表里`unref`来取消索引。其中的优化方案，还要后续有空探究。

## 遍历数据

lua本身遍历数据采用`pairs`与`ipairs`两种方式，但是对于`lnodelist`的链表来说，存在两个问题——首先，`pairs`跟`ipairs`是无状态的。对于列表类型，我们采用`ipairs`遍历时，通常为索引自增后再调用`ipair`函数执行，但对于链表，根据索引寻找会增加性能开销，并且`l_node`结点本身并非lua原生的数据类型。因此，现在暂时的解决方案是采用`Javascript`的模式call回调函数进行遍历。比如`foreach`的实现，可以如下：

```c
/* foreach loop for stateful iteration */
static int list_foreach(lua_State *L) {
  l_list *l = check_list(L, 1);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  l_node *node = l->head;
  lua_Integer idx = 0;
  while (node != NULL) {
    lua_pushvalue(L, 2);
    push_val(L, node);
    lua_pushinteger(L, ++idx);
    lua_call(L, 2, 0);
    node = node->next;
  }
  return 0;
}
```

这样就可以实现一次遍历，`map`等方法同理

# 总结

近期刷题少了，在写`lnodelist`的过程中也渐渐找回了一点感觉。总的来说能有个小demo也不错，要把它做得更好的话，还有很多方面需要调研与改进：

- 内存管理：应当兼容lua的内存管理，并且配合lua的GC机制
- 错误控制：应当有更细的错误声明跟回滚机制
- 功能改进：完善功能，进一步兼容lua内置数据结构，比如table
- 协程支持：既然要JS Style，那还是得增加对coroutine的支持

要解决这些问题，还得再深入去研究呀！

