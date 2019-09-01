---
title: 【从零单排Golang】第三话：利用docker客户端在本地部署MySQL
date: 2019/09/01 18:50:17
categories:
- 从零单排Golang
tags:
- Golang
- docker
- docker client
- MySQL
- docker API
---

## 前言

[Github传送门](https://github.com/utmhikari/gofromzero)

最近回忆起了在学校那会儿趣事：刚开始上数据库原理课程，一开始装Microsoft SQL Server，全班同学都在吐槽，怨声载道——这个说数据库咋启动不了，那个说数据库咋卸载不干净，个个焦头烂额，实在是好一番风景。唉，那时候就在想，要是有一个类似于软件管家的东西托管Microsoft SQL Server，让我们一键安装/卸载，可不就好了。

进入工业界，接触了运维方面的知识，才了解到[docker](https://www.docker.com/)的存在。不同于当年常用的虚拟机软件（VMWare WorkStation），docker并未对操作系统的硬件支撑做虚拟化，只是操作系统的进程，但却模拟了一个操作系统的环境，因此相对于虚拟机而言，docker更加轻量。轻量的运行环境意味着基于docker的部署，在管理与调度上会更加容易。看，kubernetes！

再回到我们的学习生活，拿MySQL为例吧——有了docker，安装卸载MySQL，就会变得无比容易。首先`docker pull mysql`；而后整理一下配置——通过`-v`映射数据在本地的存储路径，通过`-p`暴露出来mysql容器的端口，通过`-e`设置MySQL密码等环境变量；之后`docker run`带上上面的设置，我们的MySQL就启动了！要彻底卸载的话，只需要三行命令：`docker stop ${MySQL容器ID}`、`docker rm ${MySQL容器ID}`与`docker image rm ${MySQL镜像ID}`，就ok了，是不是EZPZ？

正好，docker是基于Golang编写。因此本期从零单排，我们就用Golang来挑战一下如何与docker交互吧~

## 编写Golang程序部署MySQL

首先，我们研究一下相关的技术栈：官方提供的Golang客户端库[docker client](https://godoc.org/github.com/docker/docker/client)为Golang与docker间搭建了桥梁，其实质是对[docker engine api](https://docs.docker.com/engine/api/v1.24/)的抽象；而docker engine api实质则是一个HTTP后端，是对docker内部镜像与容器管理功能的抽象。

通过docker client库，我们只需关心相关的参数输入。库中的方法会自动拼装参数，发送至docker engine api，从而实现交互。docker client的一些小例子，可以参考[这里](https://docs.docker.com/develop/sdk/examples/)。

接下来，我们必须研究一下，要部署MySQL容器，需要有哪些步骤：

<!-- more -->

- 登录docker hub
- 拉取MySQL镜像
- 设置参数，启动容器
- 开启日志

这四个步骤，我们可以抽象成为四个func：

- login
- pullImage
- runImage
- logImage

那么我们的主func便是：

```go
// 主线程的上下文
var ctx = context.Background()

func LaunchMySQL() {
    log.Println("Creating docker client...")
    cli, err := client.NewEnvClient()
    if err != nil {
        log.Fatalf("Error while creating docker client! %s", err.Error())
    }
    defer closeClient(cli)
    login(cli)
    pullImage(cli)
    id := runImage(cli)
    logImage(cli, id)
}
```

四个步骤，我们分开来看：

### 登录

```go
func login(cli *client.Client) {
    log.Println("Logging in docker registry...")
    ok, err := cli.RegistryLogin(ctx, types.AuthConfig{
        Username: "用户名",
        Password: "密码",
    })
    if err != nil {
        log.Fatalf("Error while logging in docker registry! %s", err.Error())
    }
    log.Printf("%s --- Token: %s\n", ok.Status, ok.IdentityToken)
}
```

采用`RegistryLogin`方法，即可登录docker hub，之后就免去认证的步骤了~

### 拉取镜像

```go
func pullImage(cli *client.Client) {
    log.Println("Pulling MySQL Image...")
    reader, err := cli.ImagePull(
        ctx,
        "docker.io/library/mysql",
        types.ImagePullOptions{})
    if err != nil {
        log.Fatalf("Error while pulling image! %s", err.Error())
    }
    _, err = io.Copy(os.Stdout, reader)
    if err != nil {
        log.Fatalf(err.Error())
    }
    log.Println("Successfully pulled MySQL Image!")
}
```

拉取镜像步骤，需要指定镜像的完整存储位置：`docker.io/library/mysql`

### 启动容器

```go
// create and start image
func runImage(cli *client.Client) string {
    log.Println("Running MySQL Image...")
    resp, err := cli.ContainerCreate(
        ctx,
        &container.Config{
            Image: "mysql:latest",
            Env: []string{"MYSQL_ROOT_PASSWORD", "123456"},
        },
        &container.HostConfig{
            PortBindings: nat.PortMap{
                "3306/tcp": []nat.PortBinding{
                    {
                        HostIP: "0.0.0.0",
                        HostPort: "3306",
                    },
                },
            },
            Mounts: []mount.Mount{
                {
                    Type:   mount.TypeBind,
                    Source: "E:\\Tools\\MySQL",
                    Target: "/var/lib/mysql",
                },
            },
        },
        nil,
        "MySQLDB")
    if err != nil {
        log.Fatalf("Error while creating image! %s", err.Error())
    }
    log.Printf("Successfully created MySQL image: %s!\n", resp.ID)
    err = cli.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{})
    if err != nil {
        log.Fatalf("Error while starting image! %s", err.Error())
    }
    log.Println("Successfully ran MySQL image!")
    return resp.ID
}
```

基于镜像与配置，我们便可以启动一个容器

在`Config`里，设置环境变量`MYSQL_ROOT_PASSWORD`为`123456`，而后在`HostConfig里`，暴露`3306`端口（MySQL默认端口）到宿主机的`3306`端口，而后宿主机的`E:\Tools\MySQL`路径与容器里`/var/lib/mysql`路径绑定，这样mysql的数据就能在我们的本机（宿主机）持久化了

### 开启日志

```go
func logImage(cli *client.Client, containerID string) {
    log.Println("Fetching log on MySQL container...")
    reader, err := cli.ContainerLogs(ctx, containerID, types.ContainerLogsOptions{
        ShowStdout:true,
        ShowStderr:true,
        Timestamps:true,
        Follow:true,
        Details:true,
    })
    if err != nil {
        log.Fatalf("Error while logging image! %s", err.Error())
    }
    _, err = io.Copy(os.Stdout, reader)
    if err != nil {
        log.Fatalf(err.Error())
    }
}
```

在日志选项中，把所有bool项开启，日志数据便更加细节了

## 总结

golang与docker交互的例子繁不胜数，但总归还要业务来决定使用哪些功能。

另外不得不说，在9102年的今天，修习技术的同学，带的电脑必须得有个docker。
