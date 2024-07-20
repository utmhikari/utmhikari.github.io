---
title: 【Lua杂谈】服务端架构skynet简易入门项目——create-skynet
date: 2019/10/26 01:22:09
categories:
- Lua杂谈
tags:
- lua
- skynet
- 后端开发
- 教程
- create-skynet
---

## 前言

在[skynet通信原理与源码分析](https://utmhikari.github.io/2019/10/20/luatalk/skynet/)一文中，我们已经详尽地弄清楚了[skynet](https://github.com/cloudwu/skynet)地通信架构，为我们上手skynet提供了极大的帮助。因此本篇文章接续上文，正式上手使用skynet。

## skynet入门项目：create-skynet

要做一个基于skynet的项目，首先需要一个好的模板。skynet的最佳实践并非将服务卸载skynet模块中，而是将skynet当作一个单独的库/SDK看待，自己独立在另外的目录写业务逻辑。因此，笔者在数月前简单地整合了一下skynet的boilerplate项目——[create-skynet](https://github.com/utmhikari/create-skynet)，采用这个项目搭建skynet服务端结构会较为清晰。

### 服务&库的约定

在create-skynet的配置中，每个服务的lua文件入口以config中`luaservice`项为准：

- service/服务名.lua
- service/服务名/main.lua
- skynet/service/服务名.lua（默认的服务）

skynet启动时会根据服务名注册相应服务，因此自己在service下定义的服务名最好不要与skynet原有服务重名。

skynet在为每一个服务读取lua库的时候，会根据运行skynet脚本的工作目录以及config里的设置去读取，这是由config的`lua_path`与`lua_cpath`为准的。在create-skynet里，lualib的位置有：

<!-- more -->

- service/服务名/?.lua
- lualib/?.lua
- luaclib/?.so
- skynet/lualib/?.lua（默认）
- skynet/luaclib/?.so（默认）

因此后续在服务逻辑中require时，需要注意lualib文件所在的位置。

skynet更多具体的config设置，可参考[官方wiki](https://github.com/cloudwu/skynet/wiki/Config)

### 启动skynet服务

create-skynet实现了skynet最简单的sproto服务的例子。如果您对sproto不了解，可以参阅笔者的[lua专用rpc协议sproto](https://utmhikari.github.io/2019/09/12/luatalk/sproto/)一文。

在create-skynet里，config的start项指定了初始的服务入口——`main`，因此我们只需在`service/main.lua`里写内容，skynet就会自动读到。

```lua
-- service/main.lua
local skynet = require "skynet"

skynet.start(function()
    skynet.error("create-skynet start server~")
    skynet.uniqueservice("proto")
    local debug_console_port = skynet.getenv("debug_console_port")
    if debug_console_port then
        skynet.newservice("debug_console", debug_console_port)
    end
    skynet.newservice("db")
    local watchdog = skynet.newservice("watchdog")
    local watchdog_port = skynet.getenv("watchdog_port")
    skynet.call(watchdog, "lua", "start", {
        port = watchdog_port,
        nodelay = true
    })
    skynet.error("Watchdog listening on", watchdog_port)
    skynet.exit()
end)
```

在主入口`service/main.lua`中，通过`skynet.start(callback)`的形式，就可以定义该服务启动时的逻辑。首先启动了协议服务`proto`；其次通过`skynet.getenv`读取`debug_console_port`配置项，如果有则启动skynet内置`debug_console`服务；而后启动`db`服务，是一个意思意思的内存kv数据库；之后启动`watchdog`，监听配置的`watchdog_port`所对应的端口。

我们可以通过解构`watchdog`服务，从而了解skynet服务的基本样式。

```lua
-- service/watchdog/main.lua
local skynet = require "skynet"

local CMD = {}
local SOCKET = {}
local gate
local agent = {}

function SOCKET.open(fd, addr)
    skynet.error("New client from : " .. addr)
    agent[fd] = skynet.newservice("agent")
    skynet.call(agent[fd], "lua", "start", {
        gate = gate, client = fd, watchdog = skynet.self()
    })
end

local function close_agent(fd)
    local a = agent[fd]
    agent[fd] = nil
    if a then
        skynet.call(gate, "lua", "kick", fd)
        -- disconnect never return
        skynet.send(a, "lua", "disconnect")
    end
end

function SOCKET.close(fd)
    print("socket close",fd)
    close_agent(fd)
end

function SOCKET.error(fd, msg)
    print("socket error",fd, msg)
    close_agent(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
end

function CMD.start(conf)
    skynet.call(gate, "lua", "open" , conf)
end

function CMD.close(fd)
    close_agent(fd)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)
    gate = skynet.newservice("gate")
end)
```

在`watchdog`服务主入口的代码中，出现了`skynet.dispatch`，它会为某个类型的消息注册回调函数从而进行处理。如果哪个服务调用了`skynet.send/call(watchdog地址, "lua", ...)`，那么`watchdog`就会拿回调函数跟后边`...`的参数凑上去，执行业务逻辑了。

在skynet架构中，`watchdog`与内置的网关服务`gate`是强耦合的。我们可以看到`watchdog`在刚启动时也会新增`gate`服务，然后`service/main.lua`调用`skynet.call(watchdog, "lua", "start", 配置)`时，`watchdog`主入口中对应的`CMD.start`就会被执行，然后在`gate`调用的`gateserver.lua`中，`CMD.open`的开启端口监听的逻辑被执行了。之后，如果有新的连接，`gate`会通知`watchdog`新连接的fd跟地址，并且而`watchdog`只需要负责新增`agent`服务，根据socket的不同情况执行相应回调管理`agent`就好了。

在`agent`服务里，只需要根据连接的fd，读取或发送数据就好，网关服务`gate`会帮你分包。这里`agent`主入口也采用官方例子中的代码，基本的套路也是一方面不断read这个fd出来的数据，识别sproto，然后调用`db`服务存取数据；另一方面会隔一段时间向fd写入心跳包，实现双工长连接tcp。此处便不再赘述啦~

## 总结

skynet的基本用法便是如此，后面还有很多挖掘点，可以查看wiki等资料深入探索~
