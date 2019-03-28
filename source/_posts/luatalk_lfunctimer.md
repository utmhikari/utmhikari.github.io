---
title: 【Lua杂谈】Lua性能测试：函数执行时间统计
date: 2019/03/25 21:15:04
categories:
- Lua杂谈
tags:
- lua
- 测试
- 性能测试
- 函数执行时间
---

# 前言

在白盒性能测试（profiling）中，函数时间统计是一项重要的指标。对于整个以lua为基础的系统架构而言，函数时间统计数据是性能优化的直接参照。

因此，本次Lua杂谈，将会分享一种函数执行时间统计的实现~

<!-- more -->

# 函数执行时间获取

单个函数执行时间的获取相对较为简单，例子如下：

```lua
local function test()
	local start = os.clock()
	...
	local end = os.clock()
	print(tostring(end - start))
end
```

在函数的开头与结尾调用lua内置的os.clock（内核实现为time.h的中`clock()`时间戳除以`CLOCKS_PER_SEC`统计量，单位为秒），可以轻而易举地获得该函数的执行时间

# hook实现

在lua的debug库中，hook掩码包括line、call、return等几种，易知在call与return事件打hook，可以更精确地对函数时间进行统计。

函数执行时间的hook可以参考笔者的[lfunctimer](https://github.com/utmhikari/lfunctimer)，在实现上参考了[luacov](https://keplerproject.github.io/luacov/index.html)以及lua官网的[函数统计样例](https://www.lua.org/pil/23.3.html)。

函数时间统计中有一个核心的问题就是递归调用自身情况，对与这个问题的处理方案是——以最早call至最晚return的时间为准。为此，对于每一个函数，设立一个stack记录时间点，每call一次push时间点，每return一次pop时间点，如果剩最后一个，就增加时间量。代码参考如下：

```lua
if evt == "call" then
    if not functimestack[f] then
        functimestack[f] = {}
    end
    table.insert(functimestack[f], os.clock())
elseif evt == "return" then
    if functimestack[f] then
        if #functimestack[f] == 1 then
            local exec_time = os.clock() - functimestack[f][1]
            lfunctimer.save(funcnames[f], exec_time)
        end
        table.remove(functimestack[f])
    end
end
```

# 总结

lua函数执行时间的统计从实现原理上并不难，甚至可以与曾经所提到的覆盖率统计模块精密结合

因此，又是一个扩展性非常强的测试需求啦~


