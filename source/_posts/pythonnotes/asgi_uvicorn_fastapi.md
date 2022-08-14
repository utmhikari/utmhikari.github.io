---
title: 【Python随笔】python的web开发——WSGI、ASGI、uvicorn与FastAPI
date: 2022/08/14 15:40:31
categories:
- Python随笔
tags:
- python
- WSGI
- ASGI
- uvicorn
- fastapi
---

今天这篇文章，聊一下`python`在`web`开发上的一些基础实现，阐述下自己理解中的`WSGI`、`ASGI`，以及拿`uvicorn`+`FastAPI`的组合举个`ASGI`应用的例子。

## WSGI

`python`的`web`服务的诞生，其实追溯到一种机制，叫做`WSGI`，全称`Web Server Gateway Interface`。`WSGI`的提案来源于[PEP-333](https://peps.python.org/pep-0333/)，可以理解为一种`python-web-server`和`python-web-app`的接口通信标准。在这种场景下，`python`的`web`服务呈现以下的工作模式：

- `python-web-app`，也就是`web`应用层，实现`WSGI`接口，用作`web`请求的`handler`
- 用户向`python-web-server`发送`web`请求
- `python-web-server`，又称作`WSGI Server`，解析请求数据，整理当前`session`的环境信息
- `python-web-server`加载`python-web-app`，调用`python-web-app`实例的`WSGI`接口，处理请求
- `python-web-app`处理完请求，返回结果给到`python-web-server`
- `python-web-server`写回返回结果，给回用户
  
代码上是这样的表现，以官方提案的例子为例：

<!-- more -->

```python
import os, sys

# python-web-app
def simple_app(environ, start_response):
    """
    python-web-app implementation
    :param environ: 由python-web-server提供，表示当前请求的环境信息
    :param start_response: 由python-web-server提供的回调，用以初始化返回结果的状态
    :return: 返回结果的数据内容
    """
    status = '200 OK'
    response_headers = [('Content-type', 'text/plain')]
    start_response(status, response_headers)
    return ['Hello world!\n']


# python-web-server
def run_with_cgi(application):
    """
    WSGI layer implementation
    :param application: 实现WSGI的app
    """
    environ = dict(os.environ.items())
    headers_set = []
    headers_sent = []

    def write(data):
        """写回数据的逻辑"""
        if not headers_set:
             raise AssertionError("write() before start_response()")
        elif not headers_sent:
             # Before the first output, send the stored headers
             status, response_headers = headers_sent[:] = headers_set
             sys.stdout.write('Status: %s\r\n' % status)
             for header in response_headers:
                 sys.stdout.write('%s: %s\r\n' % header)
             sys.stdout.write('\r\n')
        sys.stdout.write(data)
        sys.stdout.flush()

    def start_response(status, response_headers, exc_info=None):
        """初始化response的逻辑"""
        if exc_info:
            try:
                if headers_sent:
                    raise exc_info[0], exc_info[1], exc_info[2]
            finally:
                exc_info = None     # avoid dangling circular ref
        elif headers_set:
            raise AssertionError("Headers already set!")
        headers_set[:] = [status, response_headers]
        return write

    # 调用应用层的WSGI接口，获取返回数据
    result = application(environ, start_response)
    try:
        for data in result:  # 写回返回数据
            if data:    # don't send headers until body appears
                write(data)
        if not headers_sent:
            write('')   # send headers now if body was empty
    finally:
        if hasattr(result, 'close'):
            result.close()
```

通过`WSGI`，就可以实现`python-web-app`和`python-web-server`的分离，这样无论什么`python-web-app`，只要实现了`WSGI`接口标准，就能够无缝移植到其它支持`WSGI`的`python-web-server`上。

## ASGI

自`python3`推出异步IO实现`asyncio`之后，`ASGI`也应运而生。`ASGI`的目标和`WSGI`相同，但也有一些改进点，一方面是支持`asyncio`的机制，另一方面也能够解决`WSGI`难以支持`WebSocket`之类长连接模式的问题。要深入了解`ASGI`，可以参考[这篇文档](https://asgi.readthedocs.io/en/latest/index.html)。

在`ASGI`标准下，`python-web-app`需要这样的接口实现：

```python
async def application(scope, receive, send):
    """
    python-web-app应用层实现
    :param scope: 由python-web-server提供，表示当前连接的环境信息
    :param receive: 通过这个协程，可以收到由python-web-server发来的事件
    :param send: 通过这个协程，可以写回事件给python-web-server，比如让python-web-server处理response
    """
    event = await receive()
    ...
    await send({"type": "websocket.send", "text": "Hello world!"})
```

不论是`receive`到的还是`send`出去的`event`，都会包含一个`type`字段表示这个`event`的类型，一般`type`会有：

- `http.xxx`：`http`连接、请求、返回相关
- `websocket.xxx`：`websocket`连接、请求、返回相关
- `xxx.send/receive`：收发消息相关
- `lifespan.xxx`：`web`服务生命周期相关

## ASGI案例之uvicorn+FastAPI

为了更加直观感受`ASGI`的应用，本文也顺带以`uvicorn`加`FastAPI`的组合，通过源码实现来看`ASGI`是如何串联起`python-web-server`和`python-web-app`的。

在笔者封装的简易`http-web-app`框架[start-fastapi](https://github.com/utmhikari/start-fastapi)中，就支持了通过`uvicorn`启动`FastAPI`应用。其中，`main.py`的`uvicorn`实例会加载`app`模块下的`APP`这一`FastAPI`实例，启动`web-app`应用。

```python
# ============ start-fastapi project ============

# main.py
def main() -> None:
    uvicorn.run('app:APP', **cfg)

# app/__init__.py
APP = FastAPI(**FASTAPI_CFG)
```

首先从`uvicorn.run`开始看起，其代码实现如下：

```python
# uvicorn/main.py
def run(app: typing.Union[ASGIApplication, str], **kwargs: typing.Any) -> None:
    config = Config(app, **kwargs)  # uvicorn Config实例
    server = Server(config=config)  # uvicorn Server实例，包装Config实例
    if (config.reload or config.workers > 1) and not isinstance(app, str):
        sys.exit(1)
    if config.should_reload:  # 用watchdog监测文件改动，实时重启，开发环境用
        sock = config.bind_socket()
        ChangeReload(config, target=server.run, sockets=[sock]).run()
    elif config.workers > 1:  # spawn多个worker，实现多进程的web服务
        sock = config.bind_socket()
        Multiprocess(config, target=server.run, sockets=[sock]).run()
    else:  # 默认standalone的web服务
        server.run()
```

默认会走`Server`实例的`run`方法，我们来看其中的实现：

```python
# uvicorn/server.py
class Server:
    def run(self, sockets=None):
        self.config.setup_event_loop()  # 根据uvicorn配置，动态加载EventLoop的环境
        loop = asyncio.get_event_loop()  # EventLoop走asyncio的机制
        loop.run_until_complete(self.serve(sockets=sockets))  # 启动web服务

    async def serve(self, sockets=None):
        config = self.config
        if not config.loaded:  # 加载一次配置，即Config实例
            config.load()
        self.lifespan = config.lifespan_class(config)
        self.install_signal_handlers()  # 初始化os-signal处理逻辑
        await self.startup(sockets=sockets)  # 初始化服务
        if self.should_exit:
            return
        await self.main_loop()  # 开始主循环
        await self.shutdown(sockets=sockets)  # 终止服务
```

这里有两个重要步骤：

- `config.load`：加载配置
- `startup`：启动服务器

首先看配置加载，里面会将`app`实例进行初始化：

```python
# uvicorn/config.py
class Config:
    def load(self):
        assert not self.loaded
        # 上面略，会加载http_protocol_class/ws_protocol_class/lifespan_class
        try:
            # FastAPI走这个链路，加载到先前说的app.APP实例
            self.loaded_app = import_from_string(self.app)  
        except ImportFromStringError as exc:
            logger.error("Error loading ASGI app. %s" % exc)
            sys.exit(1)

        if self.interface == "auto":  # FastAPI走的是asgi3
            if inspect.isclass(self.loaded_app):
                use_asgi_3 = hasattr(self.loaded_app, "__await__")
            elif inspect.isfunction(self.loaded_app):
                use_asgi_3 = asyncio.iscoroutinefunction(self.loaded_app)
            else:
                call = getattr(self.loaded_app, "__call__", None)
                use_asgi_3 = asyncio.iscoroutinefunction(call)
            self.interface = "asgi3" if use_asgi_3 else "asgi2"

        self.loaded = True

# fastapi/applications.py
class FastAPI(Starlette):
    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if self.root_path:
            scope["root_path"] = self.root_path
        if AsyncExitStack:
            async with AsyncExitStack() as stack:
                scope["fastapi_astack"] = stack
                await super().__call__(scope, receive, send)
        else:
            await super().__call__(scope, receive, send)  # pragma: no cover
```

可以看到`FastAPI`的`app`实现里，定义了`ASGI`，并且也在`uvicorn`的`config.load`里被识别到了。`FastAPI`继承了`Starlette`，而`Starlette`本身即是支持`ASGI`的`web`框架，为`python-web-app`提供了路由、中间件相关的应用级底层支持。`FastAPI`实际是对`Starlette`的包装，相关`handler`、`middleware`的注册也是给到`Starlette`框架里面的。针对`web-server`发来的请求，`FastAPI`在设置一些环境信息后，最终也是交由`Starlette`底层处理。

之后回到`uvicorn`，看一下`startup`的实现：

```python
# uvicorn/server.py
class Server:
    async def startup(self, sockets: list = None) -> None:
        await self.lifespan.startup()
        if self.lifespan.should_exit:
            self.should_exit = True
            return
        config = self.config

        async def handler(
            reader: asyncio.StreamReader, writer: asyncio.StreamWriter
        ) -> None:  # http-handler
            await handle_http(
                reader, writer, server_state=self.server_state, config=config
            )

        # 这里省略其他分支
        try:
            server = await asyncio.start_server(
                handler,
                host=config.host,
                port=config.port,
                ssl=config.ssl,
                backlog=config.backlog,
            )
        except OSError as exc:
            logger.error(exc)
            await self.lifespan.shutdown()
            sys.exit(1)
        
        # 下略
```

`startup`分两步：

- 初始化`lifespan`
- 定义`http-handler`，通过`asyncio.start_server`启动`http-server`

在初始化`lifespan`过程中，`uvicorn`会发送`lifespan.startup`事件，这个事件就会被`FastAPI-app`的`ASGI`捕获到，最终层层往下，会走到`Starlette`的`Router`实例：

```python
# starlette/routing.py
class Router:
    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        assert scope["type"] in ("http", "websocket", "lifespan")
        if "router" not in scope:
            scope["router"] = self
        if scope["type"] == "lifespan":
            await self.lifespan(scope, receive, send)  # 走到这里
            return
        # 下略

    async def lifespan(self, scope: Scope, receive: Receive, send: Send) -> None:
        first = True
        app = scope.get("app")
        await receive()
        try:
            if inspect.isasyncgenfunction(self.lifespan_context):
                async for item in self.lifespan_context(app):  # 调用lifespan-event
                    first = False
                    await send({"type": "lifespan.startup.complete"})
                    await receive()
            # 下略
        except Exception as e:
            pass
```

当`Startlette`的`Router`检测到`lifespan`事件时，就会走到`lifespan`逻辑，其中会看`lifespan`的当前阶段是否有对应的`hook`函数，有的话就执行。当前阶段是`lifespan.startup`，因此如果我们在`FastAPI`中定义了这个协程，就可以在`startup`阶段执行到：

```python
# register startup event
@APP.on_event('startup')
async def start_app():
    pass
```

`lifespan.startup`之后，就定义`http-handler`并绑到`listen-server`上。`http-handler`会解析请求数据，然后调用`app`的`ASGI`接口处理请求，大致是这样的链路：

```python
class H11Protocol(asyncio.Protocol):
    def handle_events(self):
        while True:
            if event_type is h11.Request:
                task = self.loop.create_task(self.cycle.run_asgi(app))

class RequestResponseCycle:
    async def run_asgi(self, app):
        try:
            result = await app(self.scope, self.receive, self.send)
        except Exception as e:
            pass
```

好比我们`GET`健康检查接口`/api/v1/core/health`，那么最终被`FastAPI-app`捕获到的请求数据里，`scope`长这样：

```python
scope = {
    "type": "http",
    "method": "GET",
    "root_path": ""
    "path": "/api/v1/core/health",
    "query_string": b""
}
```

根据这些信息，层层往下，就会又走到`Starlette`的路由逻辑：

```python
# starlette/routing.py
class Router:
    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        # 上略
        # 有全部匹配的路由就直接处理
        for route in self.routes:
            match, child_scope = route.matches(scope)
            if match == Match.FULL:
                scope.update(child_scope)
                await route.handle(scope, receive, send)  # 路由实例来handle
                return
            elif match == Match.PARTIAL and partial is None:
                partial = route
                partial_scope = child_scope
        # 匹配部分匹配的路由
        if partial is not None:
            scope.update(partial_scope)
            await partial.handle(scope, receive, send)  
            return
        # 重定向
        if scope["type"] == "http" and self.redirect_slashes and scope["path"] != "/":
            redirect_scope = dict(scope)
            if scope["path"].endswith("/"):
                redirect_scope["path"] = redirect_scope["path"].rstrip("/")
            else:
                redirect_scope["path"] = redirect_scope["path"] + "/"
            for route in self.routes:
                match, child_scope = route.matches(redirect_scope)
                if match != Match.NONE:
                    redirect_url = URL(scope=redirect_scope)
                    response = RedirectResponse(url=str(redirect_url))
                    await response(scope, receive, send)
                    return
        # 默认逻辑
        await self.default(scope, receive, send)
```

由于我们在`start-fastapi`项目中，通过`APIRouter`定义了这个路由的`handler`，注册到了`Starlette`中：

```python
# ============ start-fastapi ============
# core/handler/base.py
ROUTER = APIRouter()


@ROUTER.get('/api/v1/core/health')
def health_check():
    return Resp.ok(message='ok')
```

那么`/api/v1/core/health`就会被完整匹配，走到对应路由实例的`handle`步骤：

```python
# starlette/routing.py
class Route(BaseRoute):
    async def handle(self, scope: Scope, receive: Receive, send: Send) -> None:
        if self.methods and scope["method"] not in self.methods:  # 没有对应的method
            if "app" in scope:
                raise HTTPException(status_code=405)
            else:
                response = PlainTextResponse("Method Not Allowed", status_code=405)
            await response(scope, receive, send)
        else:  # 有method，直接处理
            await self.app(scope, receive, send)

            
def request_response(func: typing.Callable) -> ASGIApp:
    is_coroutine = iscoroutinefunction_or_partial(func)
    async def app(scope: Scope, receive: Receive, send: Send) -> None:
        request = Request(scope, receive=receive, send=send)
        if is_coroutine:
            response = await func(request)
        else:
            response = await run_in_threadpool(func, request)
        await response(scope, receive, send)
    return app


# fastapi/routing.py
def get_request_handler() -> Callable[[Request], Coroutine[Any, Any, Response]]:
    raw_response = await run_endpoint_function(
        dependant=dependant, values=values, is_coroutine=is_coroutine
    )
    
 
async def run_endpoint_function(
    *, dependant: Dependant, values: Dict[str, Any], is_coroutine: bool
) -> Any:
    assert dependant.call is not None, "dependant.call must be a function"
    if is_coroutine:
        return await dependant.call(**values)
    else:
        return await run_in_threadpool(dependant.call, **values)
    
    
async def run_in_threadpool(
    func: typing.Callable[..., T], *args: typing.Any, **kwargs: typing.Any
) -> T:
    loop = asyncio.get_event_loop()
    if contextvars is not None:  # pragma: no cover
        # Ensure we run in the same context
        child = functools.partial(func, *args, **kwargs)
        context = contextvars.copy_context()
        func = context.run
        args = (child,)
    elif kwargs:  # pragma: no cover
        func = functools.partial(func, **kwargs)
    return await loop.run_in_executor(None, func, *args)
```

由于我们对健康检查路由定义了`GET`方法，那么这个路由就支持处理。最终来到了`FastAPI`的`run_endpoint_function`方法，调用我们定义的`Controller`。由于我们是直接`def health_check()`，因此会走到`loop.run_in_executor`线程池方法，去执行`Controller`，然后返回结果。否则如果是`async def`定义的`Controller`的话，就直接`await`。

所以整个请求返回的链路就完成了，而且我们也会看到，针对需要耗时耗`CPU`的请求，尽量不要用`async def`定义`FastAPI`的`Controller`，否则会有阻塞整个`asyncio`事件循环的风险，而用线程池处理就可以规避这种情况。
