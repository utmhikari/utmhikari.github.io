---
title: 【Lua杂谈】解锁lua代码覆盖率测试：luacov源码分析
date: 2019/03/10 23:23:06
categories:
- Lua杂谈
tags:
- lua
- 测试
- 代码覆盖率
- debug
- luacov
---

Lua 杂谈系列，就以代码覆盖率测试的 luacov 开头吧

## 简介

说到 lua 的覆盖率测试，我们一般都会想到用[luacov](https:--keplerproject.github.io/luacov/index.html)做代码覆盖率测试
在[干货｜使用 luacov 统计 lua 代码覆盖率](https:--blog.csdn.net/O4dC8OjO7ZL6/article/details/78373117)一文中，介绍了基本的 luacov 用法，但是缺少对 luacov 深入挖掘的相关内容。并且同时，原生的 luacov 提供了一套简洁的覆盖率测试实现以及报告输出形式，但是在实际许多场景中，采用原生 luacov 还是远远满足不了需求的
因此，本文旨在通过分析 luacov 的实现，帮助希望了解 lua 代码覆盖率测试或是使用、二次开发 luacov 的同学尽快上手

## 获取代码覆盖率数据

luacov 获取代码覆盖率数据，得益于 lua 自带的 debug 库。我们从 luacov 的主类 runner 中，可以一探究竟

<!-- more -->

```lua
-- 初始化runner
function runner.init(configuration)
    -- 读取设置
    runner.configuration = runner.load_config(configuration)
    -- 重载os.exit，在原生os.exit()前把剩下数据存掉，或者输出报告之类
    os.exit = function(...)
        on_exit()
        raw_os_exit(...)
    end
    -- 在'l'事件加debug hook
    debug.sethook(runner.debug_hook, "l")
    -- 如果每个thread都有独立的hook
    if has_hook_per_thread() then
        -- 重载coroutine.create，打包函数之前先在'l'事件sethook
        local rawcoroutinecreate = coroutine.create
        coroutine.create = function(...)
            local co = rawcoroutinecreate(...)
            debug.sethook(co, runner.debug_hook, "l")
            return co
        end
        -- coroutine.wrap用的error handler
        local function safeassert(ok, ...)
            if ok then
                return ...
            else
                error(..., 0)
            end
        end
        -- 重载coroutine.wrap，打包函数之前先在'l'事件sethook
        coroutine.wrap = function(...)
            local co = rawcoroutinecreate(...)
            debug.sethook(co, runner.debug_hook, "l")
            return function(...)
                return safeassert(coroutine.resume(co, ...))
            end
        end
    end
end
```

lua 的`debug.sethook([thread], hook, mask)`函数可以使得我们的 lua 脚本在运行过程中，遇到特定的条件（mask）时执行相应的函数（hook）。当 mask 为`'l'`时，表示 lua 脚本已经执行到了新的一行。因此，为了统计覆盖率，只需要在我们 hook`'l'`事件的函数中，寻找执行的文件和行号就好了

## hook 函数

在 luacov.runner 中，定义的 debug hook 为：

```lua
runner.debug_hook = require(cluacov_ok and "cluacov.hook" or "luacov.hook").new(runner)
```

因此我们可以以 luacov.hook 模块为例观察具体实现：

```lua
function hook.new(runner)
    -- 忽略的文件列表
    local ignored_files = {}
    -- hook执行的次数count
    local steps_after_save = 0
    -- hook函数参数为(事件evt, 行数line_nr, 栈层次level)
    return function(_, line_nr, level)
        -- level默认值为2
        -- 栈层次为1位调用hook的luacov，栈层次为2即为待测覆盖率的文件
        level = level or 2
        -- 判断runner是否初始化
        if not runner.initialized then
            return
        end
        -- 获取栈层次level的source源文件信息，即文件名
        -- 这个时候，我们就已经获得了想要的信息：文件名name与行数line_nr
        local name = debug.getinfo(level, "S").source
        -- 判断文件名前面有没@，以及是不是loadstring读取的（不然就不是文件名）
        local prefixed_name = string.match(name, "^@(.*)")
        if prefixed_name then
            name = prefixed_name
        elseif not runner.configuration.codefromstrings then
            return
        end
        -- 读取临时缓存runner.data里边的数据
        local data = runner.data
        local file = data[name]
        -- 判断该文件的数据是否要存储
        if not file then
            if ignored_files[name] then
                return
            elseif runner.file_included(name) then
                file = {max = 0, max_hits = 0}
                data[name] = file
            else
                ignored_files[name] = true
                return
            end
        end
        -- 修正该文件最大hit到的行数
        if line_nr > file.max then
            file.max = line_nr
        end
        -- 更新该文件行的hit数
        local hits = (file[line_nr] or 0) + 1
        file[line_nr] = hits
        if hits > file.max_hits then
            file.max_hits = hits
        end
        -- 判断tick步长，决定是否存储数据
        if runner.tick then
            steps_after_save = steps_after_save + 1
            if steps_after_save == runner.configuration.savestepsize then
                steps_after_save = 0
                if not runner.paused then
                    runner.save_stats()
                end
            end
        end
    end
end
```

可以看到整一个 hook 中最有价值的部分还是`local name = debug.getinfo(level, "S").source`。lua 原生的 debug.getinfo 相较于 c api 的性能差，因此建议实际需求使用中引入[cluacov](https:--github.com/LuaDist-testing/cluacov)的 hook 模块作为 hook 函数

## 总结

lua 覆盖率信息的收集，总体无非如我们在 luacov 所看到的：在`'l'`事件的 hook 函数中获取文件名与相应行数，然后保证每一个 lua 线程（协程）都能打上 hook。
luacov 实现总体而言也并不复杂，优化空间非常多，比如 save_stats()可以修改为 socket、websocket 一类实时传送数据，从而避免原生 luacov 设置 step 过小时导致报告文件 io 频繁，造成数据丢失。当然，有了网络传输，原配的很多参数都不需要了。
再深入一点，代码文件翻译成机器码，毕竟是状态机使然。如果细心观察 luacov 覆盖率的结果的话，会发现有很多该 hit 的行会 hit 不到。这些种种，就留待后续发掘啦~
