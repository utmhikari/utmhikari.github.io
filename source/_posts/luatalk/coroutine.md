---
title: 【Lua杂谈】一文上手coroutine协程
date: 2019/08/25 16:31:28
categories:
- Lua杂谈
tags:
- lua
- coroutine
- 协程
- 异步
- 洋葱圈模型
---

## 前言

提到lua，就不得不提协程coroutine。coroutine是lua的一种内在机制，为lua提供了原生的异步支持。从用户层面来看，用户不需关心coroutine的内在实现，而只需要用coroutine调度function即可，因此非常方便。

对于一个function而言，coroutine可以将function的代码分片，使得一个function可以分阶段运行。在实现上，function的状态管理会与CPU的机制相似。如果把一个function当做一个任务来看待的话，在coroutine的封装下，这个任务会被分解成多个阶段的子任务。这样，我们就可以把多个任务的子任务相互协调调度，实现更加灵活的功能交互。

因此，本期Lua杂谈，就来小试一抔coroutine的使用吧。

## coroutine的基本用法

官方5.3.5版本的coroutine库，提供了如下的接口：

```c
// lcorolib.c
static const luaL_Reg co_funcs[] = {
  {"create", luaB_cocreate},
  {"resume", luaB_coresume},
  {"running", luaB_corunning},
  {"status", luaB_costatus},
  {"wrap", luaB_cowrap},
  {"yield", luaB_yield},
  {"isyieldable", luaB_yieldable},
  {NULL, NULL}
};
```

用户可以通过`coroutine.wrap`与`coroutine.create`两种方式封装一个function（任务）。通过`wrap`封装任务会返回一个纯粹的lua函数（type为function），而用`create`封装则返回的是一个封装好的线程。

在Lua中，线程thread与协程coroutine的概念内涵有较多相似之处，但我们可以认为，线程是更加宏观广泛的概念，协程则是一种特殊的线程。线程强调的不同的`routine`之间运行是否独立；而协程强调的则是不同`routine`之间具有相互`co`的协作功能。

基于这两种方式调度任务的代码写法大同小异。以下以`create`封装任务为例，我们一起看看会是怎样的进行——

<!-- more -->

```lua
local function output(co, ...)
    print("Info:")
    print("\tSTATUS:", coroutine.status(co))
    print("\tRUNNING:", coroutine.running())
    print("\tYIELDABLE:", coroutine.isyieldable())
    if ... then
        print("Output: ")
        for _, v in ipairs({...}) do
            print("", tostring(v))
        end
    end
    print("----------------------------------------\n")
end

local co

co = coroutine.create(function(a, b)
    local ab = a + b
    output(co)
    local c, d = coroutine.yield(ab)
    coroutine.resume(coroutine.create(function (co_thread) output(co_thread) end), co)
    local cd = c + d
    output(co)
    local e, f = coroutine.yield(cd)
    output(co)
    return tostring(e) .. tostring(f)
end)

local ok1, ret1 = coroutine.resume(co, 1, 2)
output(co, tostring(ok1) .. ": " .. tostring(ret1))

local ok2, ret2 = coroutine.resume(co, 11, 22)
output(co, tostring(ok2) .. ": " .. tostring(ret2))

local ok3, ret3 = coroutine.resume(co, 111, 222)
output(co, tostring(ok3) .. ": " .. tostring(ret3))
```

我们首先定义了函数`output`函数输出当前各线程的状态（普通主线程、协程均可）。在`coroutine`中封装了以下的功能查看线程信息：

- `coroutine.status`：指定一个线程，返回该线程的状态，可以是`suspended（没运行，或被切出）`、`running（正在运行）`、`dead（任务完成，或遇到错误）`以及`normal（正调着另外一个协程）`四种之一。
- `coroutine.running`：返回当前线程以及是否为主线程的boolean。
- `coroutine.isyieldable`：返回当前线程是否具有`yield`切出功能，如果是普通主线程，或者是不支持yield的C编写的线程，就不能切出。

接下来我们定义协程`co`，采用`create`封装一个任务。我们先查看输出结果：

```plain
Info:
        STATUS: running
        RUNNING:        thread: 00000000006ee6b8        false
        YIELDABLE:      true
----------------------------------------

Info:
        STATUS: suspended
        RUNNING:        thread: 00000000006e5ef8        true
        YIELDABLE:      false
Output:
        true: 3
----------------------------------------

Info:
        STATUS: normal
        RUNNING:        thread: 00000000006f2e28        false
        YIELDABLE:      true
----------------------------------------

Info:
        STATUS: running
        RUNNING:        thread: 00000000006ee6b8        false
        YIELDABLE:      true
----------------------------------------

Info:
        STATUS: suspended
        RUNNING:        thread: 00000000006e5ef8        true
        YIELDABLE:      false
Output:
        true: 33
----------------------------------------

Info:
        STATUS: running
        RUNNING:        thread: 00000000006ee6b8        false
        YIELDABLE:      true
----------------------------------------

Info:
        STATUS: dead
        RUNNING:        thread: 00000000006e5ef8        true
        YIELDABLE:      false
Output:
        true: 111222
----------------------------------------
```

然后再分解运行过程：

1. 主线程调用`coroutine.resume(co, 1, 2)`开始这个协程，其中`1, 2`为输入参数，对应任务function里的初始参数`a, b`。
2. 在协程中，把`1, 2`相加得到`3`给`ab`变量，而后`output`线程状态：`status(co)`返回了`running`表示协程`co`正在运行，而`running`与`isyieldable`则只关心哪个线程运行了它们。在协程里，`running`会返回协程地址以及`false`，代表不是主线程；而在主线程里，`running`会返回主线程地址以及`true`。同样，在协程里，`isyieldable`会返回`true`表示该线程可被`yield`，而在主线程则不行，为`false`。后面的结果也都同样。
3. 调用`coroutine.yield(ab)`切出协程，切回主线程，这一阶段返回的结果为`ab`。
4. 主线程视角下，`coroutine.resume`的返回结果为当前协程这一阶段是否没有异常（`ok`）以及协程`yield`出来的返回值。因此`ok1`与`ret1`则为`true`跟`ab`。主线程调用`output`函数查看各个线程状况，可以看到`status(co)`为`suspended`，协程`co`正在暂停状态，等待下一次`resume`；而由于在主线程，`running`与`isyieldable`分别为`true`跟`false`。
5. 主线程调用`coroutine.resume(co, 11, 22)`继续这个协程。在协程`co`的视角下，`local c, d = coroutine.yield(ab)`中的`c, d`，即为`resume`它的线程传进来的两个参数，在这里也就是`11, 22`了。
6. 协程`co`又调起另一个协程，在另一个协程调用`output`来看原来协程`co`的`status`。嘛，这一步只是为了加一个`status == "normal"`的例子。
7. 把`11 + 22`的结果`33`给`cd`，然后`output`线程状态，结果与步骤2相似。而后，再把`cd`给`yield`切出去。
8. 主线程收到返回值`ok2 = true`以及`ret2 = 33`，而后再`output`，结果也与步骤4相似。
9. 主线程再次`resume`协程`co`，输入参数`111, 222`给协程中的`e, f`，协程内部`output`状态后，最终返回了字符串`111222`，协程任务结束。此时主线程中调用`output(co)`，可以看到`co`的状态已经为`dead`。由于协程`co`没有发生异常，那么`dead`就表示协程所有的子任务都结束啦~

至此，整一个`coroutine.create`的例子已经完成。而对于`coroutine.wrap`，由于返回的是一个lua函数而非线程，因此需要通过`pcall`等手段捕获错误，从而不至于断掉主线程运行。有兴趣的同学，可以一探究竟~

## coroutine与后端洋葱圈模型

`coroutine`的重点在于`co`，在官网上，也有[排列组合](https://www.lua.org/pil/9.3.html)、[生产者——消费者](https://www.lua.org/pil/9.2.html)等表现协同任务的例子。不过本文则要搬出我们的老朋友——后端的洋葱圈模型，示意图如下：

![洋葱圈模型](/uploads/luatalk/coroutine/onion.png ''洋葱圈模型'')

后端对于数据规范、安全性等是相当有要求的。比如一个获取数据的请求到达后端，首先都要经过重重关卡检查请求的合法性，而后后端控制器才调用服务取出数据，最后返回时，还得再一个个关卡严查，才能把该带的数据带出去。洋葱圈模型的数据处理流水线，便是如此。

我们以一个例子来试试吧~

```lua
local function middleware_header(ctx)
    ctx.header["user-agent"] = "ShangQi"
    ctx.header["referer"] = "America"
    coroutine.yield()
end

local function middleware_body(ctx)
    ctx.body.data = "Chinese Hero"
    coroutine.yield()
    if ctx.body.data ~= "Chinese Hero" then
        print(ctx.header["user-agent"] .. " is not a Chinese Hero!")
    end
end

local function controller(ctx)
    if ctx.header["referer"] ~= "China" then
        ctx.body.data = "Not a Chinese man!"
    end
end

local context = { header = {}, body = {} }
handle(context, middleware_header, middleware_body, controller)
```

在这个场景里，我们要处理的数据叫`context`。`context`先经过两个`middleware`中间件`header`与`body`，通过两个关卡，才进入到正式的掌权端`controller`。

在`header`中间件中，`context`为自己的`header`加上了两个头衔：`user-agent`表示用户代理身份，这里叫做`ShangQi`；`referer`表示从哪里来，这里叫做`America`。

在`body`中间件中，`context`为自己的`body`加上了`Chinese Hero`的数据，然后切出不管，并且打赌，如果切回来不是`Chinese Hero`的话，就告诉全世界，这个`user-agent`身份不能代表`Chinese Hero`。

但在真正掌握控制大权的`controller`中，则不会为标榜`Chinese Hero`的非中国人买单。

那么，怎样实现这一过程呢？我们看一下整一个代码：

```lua
local function handle(ctx, ...)
    local handlers = {}
    local args = table.pack(...)
    -- 检查长度
    if #args == 0 then
        return false, "Error! Expected at least one handler (controller) for context!"
    end
    -- 把middleware跟controller用coroutine.create封装，插入到handlers中
    for i = 1, #args do
        if not type(args[i]) == "function" then
            return false, "Error! Handler " .. tostring(i) .. " is not a function!"
        end
        table.insert(handlers, coroutine.create(args[i]))
    end
    -- 客户端 --> middleware（上半部分） --> controller
    for i = 1, #handlers do
        local ok, err = coroutine.resume(handlers[i], ctx)
        if not ok then
            local tag = "controller"
            if i ~= #handlers then
                tag = "middleware #" .. tostring(i)
            end
            return false, "Error at " .. tag .. "! " .. err
        end
    end
    -- 移除controller
    table.remove(handlers)
    -- 客户端 <-- middleware（下半部分） <-- controller
    while #handlers > 0 do
        local co = table.remove(handlers)
        if coroutine.status(co) == "suspended" then
            local ok, err = coroutine.resume(co, ctx)
            if not ok then
                return false, "Error at middleware #" .. tostring(#handlers + 1) .. "! " .. err
            end
        else
            -- strict mode, call coroutine.yield() forcibly
            return false, "Error at middleware #" .. tostring(#handlers + 1) .. "! Please cast coroutine.yield() in strict mode!"
        end
    end
    return true, nil
```

我们可以把所有的中间件与控制器处理任务都封装成协程，然后入栈（`table.insert`）。最后一个处理者（handler），也就是控制器处理完毕后，开始将一个个协程pop（`table.remove`）出来，再`resume`，这样，就能够模拟洋葱圈模型的操作了。

## 总结

lua的coroutine非常灵活。配合各种底层架构，可以玩出很多种不同的花样。多上手试试吧~
