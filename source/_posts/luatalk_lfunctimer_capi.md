---
title: 【Lua杂谈】debug.getinfo源码分析——使用C API重写lfunctimer
date: 2019/04/07 15:47:30
categories:
- Lua杂谈
tags:
- lua
- 测试
- lfunctimer
- lua C API
- debug
---

## 前言

昨天更新了一下[lfunctimer](https://github.com/utmhikari/lfunctimer)，主要把hook更改为c api的形式，并且初步加了util和config的扩展

想要试用的同学的话可以点击上面clone下来，或者安装[luarocks](https://luarocks.org/)后执行下面命令安装~

`luarocks install --server=http://luarocks.org/manifests/utmhikari lfunctimer`

言归正传，利用lua原生的c api做debug相关操作会比lua自带的`debug.getinfo`来的快许多，我们可以来一探究竟

## debug.getinfo源码分析

我们可以从官方下载源码搜索`debug.getinfo`的实现，此处以版本5.3.5为例。

`debug.getinfo`对应的源码是`ldblib.c`的`db_getinfo`函数，我们可以简单在`ldblib.c`的末尾中查到~

<!-- more -->

```c
static const luaL_Reg dblib[] = {
  // 略过前面
  {"getinfo", db_getinfo},
  // 略过后面
};


LUAMOD_API int luaopen_debug (lua_State *L) {
  luaL_newlib(L, dblib);
  return 1;
}
```

lua提供一个注册表（Registry）机制去把我们的函数名跟函数对应起来，然后最后要让lua识别这个模块的话，就定义一个函数，名称为`luaopen_模块名`，然后通过`luaL_newlib`方法读取前面的`luaL_Reg`注册表数据变成一个函数名——函数的table就ok了。

像`debug`之类的lua内置库，则在起lua的时候就调用`linit.c`里的`luaL_openlibs`方法就载入；而如果是第三方库，你在require的时候，则会通过`loadlib.c`中的方法去寻找模块有无载入过，如果载入过则用载入过的模块(`package.loaded`)，如果没载入过就载入，并且加到载入过模块中。这部分不再细究啦，有兴趣的同学可以自行发掘，我有空的话也会自己再踩踩坑~

我们再回头看`ldblib.c`的`db_getinfo`函数，也就是`debug.getinfo`对应的实现，代码如下：

```c
// debug.getinfo([thread,] f [,what]): 获取当前运行函数的信息
// thread (optional): 要获取函数所在的lua state（默认当前lua state）
// f: 调用栈层次（0是当前函数，1是当前函数caller，往上类推）
// what (optional)：获取的信息有哪些（默认全部）
static int db_getinfo (lua_State *L) {
  lua_Debug ar;
  int arg;
  // 参数检验部分
  lua_State *L1 = getthread(L, &arg);  // 读取thread参数
  const char *options = luaL_optstring(L, arg+2, "flnStu");
  checkstack(L, L1, 3);
  // 获取func本身/CallInfo
  if (lua_isfunction(L, arg + 1)) {  /* info about a function? */
    options = lua_pushfstring(L, ">%s", options);  /* add '>' to 'options' */
    lua_pushvalue(L, arg + 1);  /* move function to 'L1' stack */
    lua_xmove(L, L1, 1);
  }
  else {  /* stack level */
    if (!lua_getstack(L1, (int)luaL_checkinteger(L, arg + 1), &ar)) {
      lua_pushnil(L);  /* level out of range */
      return 1;
    }
  }
  // 获取附加信息flnStu之类的
  if (!lua_getinfo(L1, options, &ar))
    return luaL_argerror(L, arg+2, "invalid option");
  // push table，作为最后结果
  lua_newtable(L);  /* table to collect results */
  if (strchr(options, 'S')) {
    settabss(L, "source", ar.source);
    settabss(L, "short_src", ar.short_src);
    settabsi(L, "linedefined", ar.linedefined);
    settabsi(L, "lastlinedefined", ar.lastlinedefined);
    settabss(L, "what", ar.what);
  }
  if (strchr(options, 'l'))
    settabsi(L, "currentline", ar.currentline);
  if (strchr(options, 'u')) {
    settabsi(L, "nups", ar.nups);
    settabsi(L, "nparams", ar.nparams);
    settabsb(L, "isvararg", ar.isvararg);
  }
  if (strchr(options, 'n')) {
    settabss(L, "name", ar.name);
    settabss(L, "namewhat", ar.namewhat);
  }
  if (strchr(options, 't'))
    settabsb(L, "istailcall", ar.istailcall);
  if (strchr(options, 'L'))
    treatstackoption(L, L1, "activelines");
  if (strchr(options, 'f'))
    treatstackoption(L, L1, "func");
  return 1;  /* return table */
}
```

可以看到如果在每次调用`debug.getinfo`会经历`参数检验——获取func或CallInfo信息——获取附加信息（what）`的过程，每次都会创建一个`lua_Debug`结构体，在lua中返回的是一个table，相对繁琐一些。为了提高效率，我们可以直接用`db_getinfo`中的`lua_getstack`跟`lua_getinfo`方法去在我们的c hook中获取函数信息。

## 用C API重写lfunctimer的hook

在新版lfunctimer中，第一版C Hook实现如下：

```c
#ifndef LFUNCTIMER_UPVAL_IDX
#define LFUNCTIMER_UPVAL_IDX 1
#endif

#ifndef LFUNCTIMER_FUNCMAP_UPVAL_IDX
#define LFUNCTIMER_FUNCMAP_UPVAL_IDX 2
#endif

// push function name to top of stack
// not the same as builtin "getfuncname" method
static int lfunctimer_getfuncname(lua_State *L) {
    lua_Debug ar;
    if (!lua_getstack(L,  LFUNCTIMER_STKLVL, &ar)) {
        return 0;
    }
    // check if function name already exists
    lua_getinfo(L, "f", &ar);
    lua_pushvalue(L, -1);
    lua_gettable(L, lua_upvalueindex(LFUNCTIMER_FUNCMAP_UPVAL_IDX));
    if (lua_toboolean(L, -1)) {
        lua_remove(L, 1);  // remove funcinfo
        return 1;
    }
    lua_pop(L, 1);
    // check if it's a builtin function
    lua_getinfo(L, "Sn", &ar);
    const char *what = ar.what;
    if (strcmp(what, "C") == 0) {
        lua_pushfstring(L, "<Builtin> %s", ar.name);
    } else if (ar.namewhat[0] == '\0') {
        lua_pushfstring(L, "<%s:%d> ::UNKNOWN::", ar.short_src, ar.linedefined);
    } else {
        lua_pushfstring(L, "<%s:%d> %s", ar.short_src, ar.linedefined, ar.name);
    }
    // save function name to function map
    lua_pushvalue(L, 1);
    lua_pushstring(L, lua_tostring(L, -2));
    lua_settable(L, lua_upvalueindex(LFUNCTIMER_FUNCMAP_UPVAL_IDX));
    // remove funcinfo
    lua_remove(L, 1);
    return 1;
}
```

在某些情况下（比如loadstring）时，我们希望能够不侵入lua原生api去获取函数名称信息。因此可以这样操作——在hook函数中去上一个栈层次（level=1）的caller，我们就可以`getstack`后把函数信息暂存在一个`lua_Debug`结构体中，并在后续依据需求`getinfo`相应的内容。

获取函数名称的总体逻辑和上一版的lfunctimer（lua hook）基本类似，如果能获取到好书名称，就把函数名称push到`lua_State`的栈上。在后边的逻辑中，call跟return事件的handler都被分离了出来，这样就显得更加模块化了。

```c
// debug hook of lfunctimer
static int lfunctimer_debug_hook(lua_State *L) {
    const char *evt = lua_tostring(L, 1);
    lua_settop(L, 0);
    // get function name
    if (lfunctimer_getfuncname(L) == 0) {
        return 0;
    }
    // print log
    lua_getfield(L, lua_upvalueindex(LFUNCTIMER_CFG_UPVAL_IDX), "verbose");
    if (lua_toboolean(L, -1)) {
        lua_getfield(L, lua_upvalueindex(LFUNCTIMER_UPVAL_IDX), "log");
        lua_pushfstring(L, "%s: %s", lua_tostring(L, 1), evt);
        lua_call(L, 1, 0);
    }
    lua_pop(L, 1);
    // dispatch events
    if (evt[0] == 'c') {
        return handle_call(L);
    } else if (evt[0] == 'r') {
        return handle_return(L);
    }
    return 0;
}
```

## 总结

过后真的要多抽空研读下各种源码，打好基础= =mlgb的，最近为了领导毕业论文的事情，都憔悴了。
