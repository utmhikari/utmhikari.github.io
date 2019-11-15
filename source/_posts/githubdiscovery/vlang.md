---
title: 【GitHub探索】v语言上手，用vlang写一个聊天应用
date: 2019/11/16 00:06:16
categories:
- GitHub探索
tags:
- v语言
- 聊天服务器
- 服务端
- 翻译语言
- shingekinov
---

## 前言

vlang（v语言）自从6月份突然炒热起来，不知不觉到了11月，正式版就要出来了，在11月的GitHub Trending榜中依然排在前10。这着实令人好奇，因此笔者决定试用一下vlang，写一个小应用，体验一下感受。

## v语言上手

v语言可以在[GitHub传送门](https://github.com/vlang/v)中clone下载，支持多操作系统，有以下的特性：

- 快速编译
- 快速转译
- 热更

其余的，还有自带的GUI库、结合Go与Rust的语言特性之类，也可以算作所谓的卖点。

安装v语言也很简单，比如在windows上，首先需要安装Visual Studio提供的MSVC环境，然后只需要：

```sh
git clone https://github.com/vlang/v.git
```

然后执行：

```sh
./make.bat
```

再设置环境变量到PATH，就能够随时随地执行vlang了。

<!-- more -->

如果要更新vlang，则只需要：

```sh
v up
```

就可以自动更新并编译了。

## 写一个聊天应用

为了试用vlang，笔者简单写了个聊天应用[shingekinov](https://github.com/utmhikari/shingekinov)，设计上暂时用了全局锁而非消息队列，然后也顺带把vlang的自带网络库熟悉了一下。

vlang并没有全局变量的说法，因此需要通过在main函数里保管指针启动实例。对于一个简单的聊天服务器实例可以如下设计：

```rust
struct Server {
    instance net.Socket
mut:
    clients map[string]net.Socket
    pairs map[string]string
    mtx sync.Mutex
}
```

`clients`存储客户端socket，而`pairs`存储聊天的一对。每一个客户端连接都采用`go`关键字（orz）创建一个单独的线程进行handle。要注册客户或者处理消息时，则上全局锁。全局锁lock方法会自动等待，所以暂时不会造成死锁。handle方法如下：

```rust
fn handle(s net.Socket, server mut Server) {
    fdint := s.sockfd
    fd := fdint.str()
    logger.info('$fd connected!!!')
    s.write('$fd: Welcome to ShinGeKiNoV Chat Platform~')
    server.mtx.lock()
    server.register(fd, s)
    server.mtx.unlock()
    for {
        msg := s.read_line().replace('\r\n', '').replace('\n', '')
        if msg.len > 0 {
            logger.info('Received message size ${msg.len} from $fd: $msg')
        }
        server.mtx.lock()
        if server.is_chatting(fd) {
            match msg {
                '' {
                    logger.warn('$fd itself disconnected...')
                    server.leave_chat(fd)
                    server.unregister(fd)
                    break
                }
                'exit' {
                    logger.warn('$fd is going to leave chat...')
                    server.leave_chat(fd)
                }
                else {
                    server.handle_chat(fd, msg)
                }
            }
        } else {
            match msg {
                '' {
                    logger.warn('$fd itself disconnected...')
                    server.leave_chat(fd)
                    server.unregister(fd)
                    break
                }
                'exit' {
                    logger.warn('$fd is requesting to disconnect...')
                    s.write('Disconnecting...')
                    server.leave_chat(fd)
                    server.unregister(fd)
                    break
                }
                'help' {
                    s.write(server.help())
                }
                'list' {
                    s.write(server.list())
                }
                'chat' {
                    server.join_chat(fd)
                }
                else {
                    s.write('Invalid command: $msg! Type "help" for options~')
                }
            }
        }
        server.mtx.unlock()
    }
}
```

值得一提的是，在做这个简单聊天服务器的同时，笔者也发现vlang当前的版本虽然看似功能非常多，但是每一个功能都还是非常稚嫩，可以说是挖了一个很大的坑。比如当前版本的map采用普通二叉树存储key（orz），并且在insert与delete上都是有bug的；再比如socket客户端断开时，没有EOF的支持...v语言，也成为了笔者码代码以来第一个需要改标准库源码才能运行成功的编程语言（orz）。

## 总结

v语言，首先是库的支持，还是太笼统了，离真正可用还差一段距离，并且没有完善GC的支持，在线上环境这一part是很致命的。

按v语言的特性来看，算是一种“翻译语言”，可以翻译为C语言，似乎也能翻译成javascript，因此挺适合做热更的需求，对于游戏开发似乎很有用喔。

总的来讲，这些细节还是得慢慢磨，期待后续吧~
