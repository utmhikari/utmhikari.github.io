---
title: 【Lua杂谈】lua专用rpc协议sproto——基础介绍&用于协议测试的二次开发
date: 2019/09/12 16:53:12
categories:
- Lua杂谈
tags:
- lua
- sproto
- 协议
- 协议测试
- rpc
---

## 前言

rpc（远程过程调用），是不同主机间的交互的机制之一。好比说，我们想要获取服务器的某个资源，我们就可以发送一条讯息给服务器，然后服务器解析信息，再返回推送资源的信息，这样，便实现了我们客户端跟服务器的相互的“远程调用”。

为了让不同主机之间能够相互理解发送的讯息，我们需要约定统一的信息格式标准，使得不同的主机可以发送基于这个信息格式的讯息，也可以解析这个格式。这种标准，我们称之为协议（protocol）。

Lua中协议选择有许多种，protobuf、json均可。但是今天，就稍微介绍一下云风同志当年为lua量身设计的sproto协议以及其用于协议测试的二次开发。So, let the party begin~

## sproto协议描述

[sproto](https://github.com/cloudwu/sproto)是专用于lua的协议框架，相对于protobuf跟json，sproto在数据的序列化/反序列化效率上有极大的优势。rpc中为了快速效率地传送协议数据，会将数据组装压缩发送，接收端再解压拆解数据识别消息，从而减小了网络传输的开销。这个数据处理过程便可称之为序列化/反序列化。

sproto的设计类似于[protobuf](https://developers.google.com/protocol-buffers/?hl=zh-CN)，基本类型为`string`、`binary`、`integer`以及`boolean`四种。对于array序列的支持，则加上引用星号`*`即可；对于非整数的支持方面，用户可以parse string来处理实数，或者指定integer的小数位数来处理小数（decimal）。除此之外，用户也可以像编程里面strcut那样自定义类型，类型与类型之间也可以嵌套。

我们可以从[readme](https://github.com/cloudwu/sproto/blob/master/README.md)中寻找各种例子。数据类型的例子如下：

<!-- more -->

```protobuf
.Person { # . means a user defined type
    name 0 : string # string is a build-in type.
    id 1 : integer
    email 2 : string

    .PhoneNumber { # user defined type can be nest.
        number 0 : string
        type 1 : integer
    }

    phone 3 : *PhoneNumber # *PhoneNumber means an array of PhoneNumber.
    height 4 : integer(2) # (2) means a 1/100 fixed-point number.
    data 5 : binary # Some binary data
}

.AddressBook {
    person 0 : *Person(id) # (id) is optional, means Person.id is main index.
}

```

每个用户自定义的数据类型需要包含子项的名称、编号（序列化时排序）与子项数据类型。基于这些数据类型，我们可以约定各种各样的协议。比如：

```protobuf
foobar 1 { # define a new protocol (for RPC used) with tag 1
    request Person # Associate the type Person with foobar.request
    response { # define the foobar.response type
        ok 0 : boolean
    }
}
```

这样，协议foobar（编号为1）请求与返回的协议数据格式便一目了然了。

至于协议的序列化设计，在云风所著[《设计一种简化的 protocol buffer 协议》](https://blog.codingnow.com/2014/07/ejoyproto.html)的Wire Protocol与“0 压缩”章节中已经详尽描述了，此处便不再赘述。

## sproto协议收发

收发协议的例子可以查看skynet网络框架的[Sproto](https://github.com/cloudwu/skynet/wiki/Sproto)一章。

sproto本身也分两层，当我们使用sproto的时候，通常调用sproto的lua嵌入层模块`sproto.lua`中的函数。真实收发sproto协议时，需要带上协议包头`header`表现协议的外在信息，比如：

- type 协议的类型——REQUEST或RESPONSE
- session 协议的标识——通过这个标识对应请求与响应

一开始，我们可以采用`sproto.parse`或`sproto.new`把自己储存的协议定义解析至内存里。通过`local host = sproto:host(包头名)`，我们便可指定包头。之后，通过`host:attach(解析的协议)`，我们可以创建一个回调函数，用来打包每个协议数据包，而相对地，通过`host:dispatch`，就可以解析每一个传输过来的协议数据了。具体操作在github项目上的[sproto.lua](https://github.com/cloudwu/sproto/blob/master/sproto.lua)都能看到，例子则可以查看[testrpc.lua](https://github.com/cloudwu/sproto/blob/master/testrpc.lua)。

## 用于协议测试的二次开发

要测试sproto，首先需要导出所有协议。在官方的实现中，[sproto.c](https://github.com/cloudwu/sproto/blob/master/sproto.c)的`void sproto_dump(struct sproto *s)`函数可以把所有协议都print出来，对应的lua接口是`require("sproto.core").dumpproto(解析的协议.__cobj))`。而在笔者自己fork的项目中，就修改了[lsproto.c（lua注册层）](https://github.com/utmhikari/sproto/blob/master/lsproto.c)的实现，增加了totable的功能。通过totable导出之后，在协议测试过程中统计协议信息就不是什么难题了。

而协议测试的一个必备功能就是从工具端发送协议，（并非从真实客户端发送），因此首先我们也需要魔改`sproto.lua`来便利测试。我们可以观察`sproto:host`函数：

```lua
function sproto:host( packagename )
    packagename = packagename or  "package"
    local obj = {
        __proto = self,
        __package = assert(core.querytype(self.__cobj, packagename), "type package not found"),
        __session = {},
    }
    return setmetatable(obj, host_mt)
end
```

其中的`__session`用于缓存每一个指定了session的包，这个缓存过程是在上面所述`host:attach`里打包回调函数实现的：

```lua
function host:attach(sp)
    return function(name, args, session, ud)
        local proto = queryproto(sp, name)
        header_tmp.type = proto.tag
        header_tmp.session = session
        header_tmp.ud = ud
        local header = core.encode(self.__package, header_tmp)

        if session then
            self.__session[session] = proto.response or true
        end

        if proto.request then
            local content = core.encode(proto.request, args)
            return core.pack(header ..  content)
        else
            return core.pack(header)
        end
    end
end
```

因此，如果要实现从工具端凭空发送协议的话，可以另外在host的obj中增加`__name`缓存每个协议名的发送信息。要凭空发一条协议时，如果`__name`中没有缓存，就再凭空生成一个session，而如果有，就根据缓存中是否包含session来判断需不需要凭空生成session。通过修改`host`与`attach`函数，就可以满足这些需求啦~

## 总结

不论是sproto，还是啥，协议测试本身实现方案众多，需求也千变万化，单靠这一篇文章，难以完全说明。

路漫漫其修远兮~
