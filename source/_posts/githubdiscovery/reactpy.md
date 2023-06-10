---
title: 【GitHub探索】用python写web前端之reactpy探索
date: 2023/06/10 11:30:39
categories:
- GitHub探索
tags:
- python
- react
- fastapi
- 前端
- web开发
---

你有想象过用python来写web前端这种操作么？近期在github-trending上就有这样的一个项目[reactpy](https://github.com/reactive-python/reactpy)，可以满足你在python上写web前端的欲望。为此，笔者也决定踩踩坑，看看这个项目的形式到底如何，能不能很方便地实际投产。

要用到这个项目，除了reactpy库本身外，还需要一个backend-implementation来部署前端开发环境到本地端口。这里我们采取的操作是`pip install reactpy[fastapi]`，这样就能直接安装上以fastapi为后端实现的前端开发环境部署。

要开始写一个简单的网页，可以参考reactpy的[官方网站](https://reactpy.dev/docs/guides/getting-started/index.html)。基本代码如下：

<!-- more -->

```python
import reactpy
from reactpy import component, html, run


@component
def reactpy_content(count):
    add_count, set_add_count = reactpy.use_state(1)
    multi_count = reactpy.use_memo(lambda: count * 3, [count])
    reactpy.use_effect(lambda: set_add_count(add_count + multi_count), [multi_count])
    return html.div(
        {
            'style': {'color': '#ff0000'}
        },
        html.ol(
            html.li(f'count: {count}'),
            html.li(f'multi_count: {multi_count}'),
            html.li(f'add_count: {add_count}')
        ),
    )


@component
def reactpy_app():
    count, set_count = reactpy.use_state(0)
    return html.div(
        html.h1('Debug Site'),
        html.button({
            'on_click': lambda e: set_count(count + 1)
        }, "Increment Count"),
        reactpy_content(count)
    )


if __name__ == "__main__":
    run(
        reactpy_app,
        host='127.0.0.1',
        port=7654
    )
```

展现出来的效果是：

![测试页面](/uploads/githubdiscovery/reactpy/debug_site.png)

可以看到这个案例里面，我们能够模拟到react的一些基本特性，包括：

- 基础的html标签
- 组件嵌套
- useState/useEffect/useMemo

可以说如果想只用python写前端，做前后端不分离的页面app，而且是一些极其简单的前端，用reactpy，其实也可以满足你的需求。甚至如果需要调用到原生js模块，也可以考虑参考[这个文档](https://reactpy.dev/docs/guides/escape-hatches/javascript-components.html)去进行。

如果从工业化的角度来说，reactpy距离大规模的前端app还有一定的距离。不仅是因为以nodejs为基础的前端生态非常成熟，而且从开发部署角度来说，reactpy一是开发时期还没有办法做到响应文件变化随时重编译，二是部署前端的方式也不能用纯python，必须要[结合nodejs的方式](https://reactpy.dev/docs/guides/escape-hatches/distributing-javascript.html)进行。所以如果考虑做复杂的，需要与后端分离的前端应用，reactpy并不是一个选择，现在还只能够作为玩具来玩。
