---
title: 【从零单排Golang】第六话：基于wire的kratos微服务框架示例项目
date: 2022/12/03 14:50:20
categories:
- 从零单排Golang
tags:
- Golang
- wire
- kratos
- 微服务
- 元编程
---

《从零单排Golang》系列，又重新开张了。后续会不定期更新自己学习`Golang`的笔记跟心得。

这次的话，就介绍一款名为奎爷`kratos`的微服务框架，以及讲述一下基础的使用机理。

`kratos`是B站开源的微服务框架，不仅提供了`grpc`、`http`协议支持，而且有较为完善的层级架构、微服务中间件以及第三方组件的编写约定，可以说是非常方便上手跟扩展。

要上手``kratos``，我们可以从两个地方入手：

- [kratos-github](https://github.com/go-kratos/kratos)
- [kratos官方文档](https://go-kratos.dev/)

通过`kratos`的[quickstart文档](https://go-kratos.dev/en/docs/getting-started/start)，我们可以创建一个名为`kratostest`的项目。项目的目录结构遵循[kratos-layout](https://github.com/go-kratos/kratos-layout)，具体如下：

<!-- more -->

- `api`：接口定义，主要是proto文件
  - 需要生成`go`文件给到`internal`或者`service`模块做请求处理实现的编写
- `cmd`：`main.go`与`wire.go`
- `configs`：配置`yaml`
- `internal`：
  - `biz`：业务逻辑
    - 若相较于`controller`或`handler`，则类似于`service`的概念
    - 此`service`不是指`kratos`的`service`
  - `conf`：配置
  - `data`：数据访问
  - `server`：对外服务
  - `service`：类似于`controller`、`handler`
- `third_party`：第三方内容

`kratostest`项目在启动之前，除了需要`go-protobuf`环境把`proto`文件编译成`go`文件之外，默认还需要通过`wire`模块自动初始化对象实例。`wire`是一种在`golang`里实现依赖注入的解决方案，可以参考以下文档，了解`wire`的作用：

- [wire-github](https://github.com/google/wire)
- [`wire`介绍博客](https://go.dev/blog/wire)

从使用角度上来说，实际上经过了如下的步骤：

- 解析各个Provider接口出入参的实现
- 根据不同Provider出入参的依赖关系，生成实际的初始化代码，填充入参，实现注入的效果

以`http-server`的基础`greeter`接口为例，存在着这样的调用层次：

- `NewHTTPServer`：在`internal/server/http.go`，生成`HTTPServer`实例
  - 入参有`conf.Server`实例，是服务器启动的配置，可以通过`internal/conf/conf.proto`生成
    - `configs/config.yaml`实际配置这些内容
  - 入参`*service.GreeterService`，该实例需要实现`GreeterHTTPServer`的接口定义
  - `GreeterHTTPServer`的接口定义实际是由`greeter.proto`定义之后自动生成的
- `NewGreeterService`：在`internal/service/greeter.go`，生成`GreeterService`实例
  - 在这里需要实现`GreeterHTTPServer`的接口定义
  - 需要定义`biz`层成员`*biz.GreeterUsecase`，在接口实现会调用这个成员方法执行实际业务
- `NewGreeterUsecase`：在`internal/biz/greeter.go`，生成`GreeterUsecase`实例
  - 需要定义`GreeterRepo`类型成员，用来做数据的CRUD
- `NewGreeterRepo`：在`internal/data/greeter.go`，生成`GreeterRepo`实例
  - 需要定义`*Data`类型成员，用来做实际对接数据库的访问操作
- `NewData`：在`internal/data/data.go`，生成`*Data`实例
  - 入参有`conf.Data`实例，是数据库的配置，可以通过`internal/conf/conf.proto`生成
  - 这些方法可以打包成`wire`的`ProviderSet`，然后一并`Build`起来

```go
// cmd/kratostest/main.go
func newApp(logger log.Logger, gs *grpc.Server, hs *http.Server) *kratos.App {
    return kratos.New(
        kratos.ID(id),
        kratos.Name(Name),
        kratos.Version(Version),
        kratos.Metadata(map[string]string{}),
        kratos.Logger(logger),
        kratos.Server(
            gs,
            hs,
        ),
    )
}

// cmd/kratostest/wire.go
func wireApp(*conf.Server, *conf.Data, log.Logger) (*kratos.App, func(), error) {
    panic(wire.Build(server.ProviderSet, data.ProviderSet, biz.ProviderSet, service.ProviderSet, newApp))
}
```

在`cmd/kratostest`执行了`wire`之后，就会把这些依赖注入，代码重新组装起来，最后生成`wire_gen.go`文件。

```go
func wireApp(confServer *conf.Server, confData *conf.Data, logger log.Logger) (*kratos.App, func(), error) {
    dataData, cleanup, err := data.NewData(confData, logger)
    if err != nil {
        return nil, nil, err
    }
    greeterRepo := data.NewGreeterRepo(dataData, logger)
    greeterUsecase := biz.NewGreeterUsecase(greeterRepo, logger)
    greeterService := service.NewGreeterService(greeterUsecase)
    grpcServer := server.NewGRPCServer(confServer, greeterService, logger)
    httpServer := server.NewHTTPServer(confServer, greeterService, logger)
    app := newApp(logger, grpcServer, httpServer)
    return app, func() {
        cleanup()
    }, nil
}
```

`wire_gen.go`的`wireApp`，最终会在`main.go`里实际执行，从而真正启动整个`kratostest`服务和各层的对象实例。

```go
func main() {
    // 忽略上面
    app, cleanup, err := wireApp(bc.Server, bc.Data, logger)
    if err != nil {
        panic(err)
    }
    defer cleanup()
    // start and wait for stop signal
    if err := app.Run(); err != nil {
        panic(err)
    }
}
```

这样，整个`kratos`服务的基础逻辑结构就顺起来了。
