---
title: 【Lua杂谈】基于lua的服务端架构——skynet通信原理与源码分析
date: 2019/10/20 03:32:12
categories:
- Lua杂谈
tags:
- lua
- skynet
- 服务端
- lua_State
- 源码分析
---

## 前言

提起中国的lua产品，就不得不想到[skynet](https://github.com/cloudwu/skynet)，一款针对游戏，但又不仅限于游戏的服务端架构。skynet充分利用了lua的特性，并且在此基础上易扩展HTTP、HTTPS、WebSocket等模块，因此由skynet入手理解lua原理以及服务端架构是一个非常不错的选择。

通过skynet，我们可以构建许多小巧而高性能、高可用的应用。废话不多说，让我们一起来探索skynet架构吧~

## skynet通信原理与源码分析

服务端架构中，不同子服务的通信调度是核心功能。因此，我们以单点（standalone）的skynet实例为例，由外而内，逐步剖析。

要介绍skynet的通信原理，首先要提到lua中的一个概念——lua_State。lua_State是lua的运行时（runtime），是一个原生隔离的、高性能的运行环境，若在多核并行运行lua_State，其性能一定不会差。lua作为嵌入式语言，以C为基础，可以实现操作系统粒度级的lua_State调度，因此skynet也就如同lua_State管理器一样了。

每一种业务可以看作一个service，而每一个service中，都会有一个lua_State充当执行业务逻辑的环境。举个例子，在实际开发当中，比如做一个HTTP服务的话，我们需要自己预先配置好的skynet service主入口lua文件中，写上`skynet.uniqueservice("app")`启动一个独特的名为`app`的服务，而后在其中的逻辑中，根据每一个HTTP连接，解析其中的数据包。并调用`skynet.newservice`动态创建单独的上下文服务`ctx`来处理这个请求。`ctx`服务还有可能需要查询数据库中的数据，并返回结果，因此我们可能还需要通过`skynet.uniqueservice("db")`预先创建数据库服务`db`二次封装skynet内置mongo、mysql库的功能，然后再通过`skynet.call`来与`db`服务通信，获得`db`服务某个函数执行的返回结果，再在`ctx`服务的处理逻辑中写入HTTP Response，从而完成整个处理过程。在这一过程中，具体业务逻辑的处理都会在各个service所拥有的lua_State中运行，但调度通信的逻辑，则就是底层的活了。

因此在skynet底层中，不仅需要支持多个lua_State的运转，而且相对更有挑战性的是，如何让service之间能够相互交流。为了解决这个问题，我们可以看到，在底层中，每一个service都属于`snlua`类型。`snlua`除了包括自己的lua_State之外，还维护了一个称之为context的运行状态：

<!-- more -->

```cpp
// lua-skynet.c
struct snlua {
    lua_State * L;
    struct skynet_context * ctx;
    const char * preload;
};

// skynet_server.c
struct skynet_context {
    void * instance;
    struct skynet_module * mod;
    void * cb_ud;
    skynet_cb cb; // 用于处理每一个消息的回调函数
    struct message_queue *queue; // context专属的message_queue
    FILE * logfile;
    uint64_t cpu_cost; // in microsec
    uint64_t cpu_start; // in microsec
    char result[32];
    uint32_t handle; // 维护一个handle，可以理解为操作系统的URL
    int session_id;
    int ref;
    int message_count;
    bool init;
    bool endless;
    bool profile;

    CHECKCALLING_DECL
};
```

在lua业务逻辑中执行`skynet.newservice`或`skynet.uniqueservice`，skynet框架就会根据服务名称读取对应入口的代码执行。要让这个服务启动，入口文件的代码还需要添加`skynet.start`函数：

```lua
-- skynet.lua
function skynet.start(start_func)
    c.callback(skynet.dispatch_message)
    init_thread = skynet.timeout(0, function()
        skynet.init_service(start_func)
        init_thread = nil
    end)
end
```

可以看到在启动之时，会通过`c.callback`注册一个回调函数用于分发消息，其逻辑如下：

```cpp
// lua-skynet.c
// 对应c.callback
static int
lcallback(lua_State *L) {
    struct skynet_context * context = lua_touserdata(L, lua_upvalueindex(1));
    int forward = lua_toboolean(L, 2);
    luaL_checktype(L,1,LUA_TFUNCTION);
    lua_settop(L,1);
    lua_rawsetp(L, LUA_REGISTRYINDEX, _cb);
    lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD);
    lua_State *gL = lua_tothread(L,-1);
    if (forward) {
        skynet_callback(context, gL, forward_cb);
    } else {
        skynet_callback(context, gL, _cb); // 调用skynet_callback注册回调函数
    }
    return 0;
}

static int
forward_cb(struct skynet_context * context, void * ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
    _cb(context, ud, type, session, source, msg, sz);
    // don't delete msg in forward mode.
    return 1;
}

static int
_cb(struct skynet_context * context, void * ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
    // 太长略过，就是在这个snlua service的lua_State上执行逻辑啦
}

// skynet_server.c
void
skynet_callback(struct skynet_context * context, void *ud, skynet_cb cb) {
    context->cb = cb; // 注册回调函数
    context->cb_ud = ud;
}
```

所以我们看到，最终处理消息的逻辑，就会注册到context的cb上。context会维护这个service专属的消息队列`message_queue`，多个service的消息队列在skynet里就被存放在一个全局唯一的队列`global_queue`中。

```cpp
// skynet_mq.c
// 每个service的context的消息队列
struct message_queue {
    struct spinlock lock;
    uint32_t handle; // 也维护一个handle，通过这个handle，能反过来找到对应的context
    int cap;
    int head;
    int tail;
    int release;
    int in_global;
    int overload;
    int overload_threshold;
    struct skynet_message *queue;
    struct message_queue *next; // 全局队列里的下一个
};

// 全局队列：双端message_queue队列
struct global_queue {
    struct message_queue *head;
    struct message_queue *tail;
    struct spinlock lock;
};
```

在skynet架构启动之际，会根据用户配置创建全局消息队列以外，还会初始化定时器、日志、socket、集群等基础模块及服务。当然在这个过程中，也会创建几个worker：

```cpp
// skynet_start.c
void
skynet_start(struct skynet_config * config) {
    // 略过上面
    skynet_mq_init();
    // 略过中间
    start(config->thread); // config中的thread配置项即为worker数
    // 略过下面
}

static void
start(int thread) {
    // 略过上面
    static int weight[] = {
        -1, -1, -1, -1, 0, 0, 0, 0,
        1, 1, 1, 1, 1, 1, 1, 1,
        2, 2, 2, 2, 2, 2, 2, 2,
        3, 3, 3, 3, 3, 3, 3, 3, }; // 每个worker的负载
    struct worker_parm wp[thread];
    for (i=0;i<thread;i++) {
        wp[i].m = m;
        wp[i].id = i;
        if (i < sizeof(weight)/sizeof(weight[0])) {
            wp[i].weight= weight[i];
        } else {
            wp[i].weight = 0;
        }
        create_thread(&pid[i+3], thread_worker, &wp[i]); // 创建worker线程
    }
    // 略过下面
}

// skynet_mq.c
void
skynet_mq_init() {
    struct global_queue *q = skynet_malloc(sizeof(*q));
    memset(q,0,sizeof(*q));
    SPIN_INIT(q);
    Q=q; // 创建全局唯一global_queue
}
```

而这些worker会做什么呢？我们查看worker线程任务的函数定义即可知晓：

```cpp
// skynet_start.c
static void *
thread_worker(void *p) {
    struct worker_parm *wp = p;
    int id = wp->id;
    int weight = wp->weight;
    struct monitor *m = wp->m;
    struct skynet_monitor *sm = m->m[id];
    skynet_initthread(THREAD_WORKER);
    struct message_queue * q = NULL;
    while (!m->quit) {
        // 当worker的监控monitor未退出时，循环运行，分发消息
        q = skynet_context_message_dispatch(sm, q, weight);
        // 略过下面
    }
    return NULL;
}

// skynet_server.c
struct message_queue *
skynet_context_message_dispatch(struct skynet_monitor *sm, struct message_queue *q, int weight) {
    if (q == NULL) { // 如果是一开始，或上一次预先取得消息队列为NULL
        q = skynet_globalmq_pop(); // 那么就尝试从全局队列中pop一个消息队列
        if (q==NULL)
            return NULL;
    }
    uint32_t handle = skynet_mq_handle(q);
    struct skynet_context * ctx = skynet_handle_grab(handle); // 找到对应的context
    if (ctx == NULL) {
        struct drop_t d = { handle };
        skynet_mq_release(q, drop_message, &d);
        return skynet_globalmq_pop(); // 预先取下一个消息队列
    }
    int i,n=1;
    struct skynet_message msg;
    for (i=0;i<n;i++) {
        if (skynet_mq_pop(q,&msg)) { // 返回值为0表示消息队列不为空
            skynet_context_release(ctx);
            return skynet_globalmq_pop();
        } else if (i==0 && weight >= 0) {
            n = skynet_mq_length(q);
            n >>= weight;
        }
        int overload = skynet_mq_overload(q);
        if (overload) {
            skynet_error(ctx, "May overload, message queue length = %d", overload);
        }
        // skynet_monitor监控了每个worker，通过version标识分发消息的次数
        // 通过skynet_monitor_trigger，可以++version标识
        // worker是一直不断运行的。如果version一直没涨
        // 就说明某一个消息在分发处理时死循环了
        skynet_monitor_trigger(sm, msg.source , handle);
        if (ctx->cb == NULL) {
            skynet_free(msg.data);
        } else {
            dispatch_message(ctx, &msg); // 分发消息给对应的context
        }
        skynet_monitor_trigger(sm, 0,0);
    }
    assert(q == ctx->queue);
    struct message_queue *nq = skynet_globalmq_pop();
    if (nq) {
        // If global mq is not empty , push q back, and return next queue (nq)
        // Else (global mq is empty or block, don't push q back, and return q again (for next dispatch)
        skynet_globalmq_push(q);
        q = nq;
    }
    skynet_context_release(ctx);
    return q;
}

static void
dispatch_message(struct skynet_context *ctx, struct skynet_message *msg) {
    // 略过前置检查逻辑
    int reserve_msg; // 是否在内存中保留消息数据？
    if (ctx->profile) { // 如果在性能测试，记录cpu时间
        ctx->cpu_start = skynet_thread_time();
        reserve_msg = ctx->cb(ctx, ctx->cb_ud, type, msg->session, msg->source, msg->data, sz);
        uint64_t cost_time = skynet_thread_time() - ctx->cpu_start;
        ctx->cpu_cost += cost_time;
    } else {
        // 不管怎么样都要调用context的消息处理回调函数处理消息
        reserve_msg = ctx->cb(ctx, ctx->cb_ud, type, msg->session, msg->source, msg->data, sz);
    }
    if (!reserve_msg) {
        skynet_free(msg->data);
    }
    CHECKCALLING_END(ctx)
}
```

也就是说，这些worker会不断地从全局队列中取出单个消息队列，而后让这个消息队列所对应的service通过其context上注册的回调函数cb，处理相应的消息。

因此到这里，消息处理这一块的逻辑已经弄清了。如果要完成通信的闭环，还需要解决两个问题：

- 发送方service如何推送消息到目标service？（`skynet.send`，非阻塞发送消息）
- 发送方如何获得目标service处理的返回值？（`skynet.call`，阻塞等待消息处理结果）

我们先来看`skynet.send`。这个函数调用了底层注册的`send`函数，对应了`lua-skynet.c`中的`lsend`函数。我们以此为起点，观察消息推送的过程：

```cpp
// lua-skynet.c
/*
    uint32 address
     string address
    integer type
    integer session
    string message
     lightuserdata message_ptr
     integer len
 */
static int
lsend(lua_State *L) {
    return send_message(L, 0, 2);
}

static int
send_message(lua_State *L, int source, int idx_type) {
    // 略过上面
    // 消息类型，一般在lua层写业务逻辑的话，都约定用string就好了
    int mtype = lua_type(L,idx_type+2);
    switch (mtype) {
    case LUA_TSTRING: {
        size_t len = 0;
        void * msg = (void *)lua_tolstring(L,idx_type+2,&len);
        if (len == 0) {
            msg = NULL;
        }
        // 我们可以指定某个服务的名称（string），或者地址（uint）
        if (dest_string) {
            // 如果指定名称，走skynet_sendname逻辑，当然最后也会寻址，再去走skynet_send逻辑。
            session = skynet_sendname(context, source, dest_string, type, session , msg, len);
        } else {
            session = skynet_send(context, source, dest, type, session , msg, len);
        }
        break;
    }
    // 略过下面
}

// skynet-server.c
int
skynet_send(struct skynet_context * context, uint32_t source, uint32_t destination , int type, int session, void * data, size_t sz) {
    // 略过参数检验部分
    if (skynet_harbor_message_isremote(destination)) {
        // 暂时略过harbor（集群）的部分
    } else {
        struct skynet_message smsg;  // 把消息数据打包到skynet_message结构体
        smsg.source = source;
        smsg.session = session;
        smsg.data = data;
        smsg.sz = sz;
        if (skynet_context_push(destination, &smsg)) {  // 推送到目标的context
            skynet_free(data);
            return -1;
        }
    }
    return session;
}

int
skynet_context_push(uint32_t handle, struct skynet_message *message) {
    struct skynet_context * ctx = skynet_handle_grab(handle);
    if (ctx == NULL) {
        return -1;
    }
    skynet_mq_push(ctx->queue, message);  // 把消息推入消息队列当中
    skynet_context_release(ctx);

    return 0;
}
```

通过这样的一顿操作，就可以把消息发送到指定service的消息队列里了，然后就等worker来取消息回调处理啦~

那么第二个，如何实现获取处理结果的需求呢？这个是在lua层实现的，通过目标服务嗲用`skynet.ret`逻辑，`skynet.call`就可以获取返回值。我们来观察两边的逻辑：

```lua
-- skynet.lua
local function yield_call(service, session)
    watching_session[session] = service -- 监控是否有收到相应session的返回数据
    session_id_coroutine[session] = running_thread
    local succ, msg, sz = coroutine_yield "SUSPEND" -- 挂起，直到该session有返回为止
    watching_session[session] = nil
    if not succ then
        error "call failed"
    end
    return msg,sz
end

function skynet.call(addr, typename, ...)
    local tag = session_coroutine_tracetag[running_thread]
    if tag then
        c.trace(tag, "call", 2)
        c.send(addr, skynet.PTYPE_TRACE, 0, tag)
    end
    local p = proto[typename]
    local session = c.send(addr, p.id , nil , p.pack(...)) -- 获取本次消息的session
    if session == nil then
        error("call to invalid address " .. skynet.address(addr))
    end
    return p.unpack(yield_call(addr, session))
end

function skynet.ret(msg, sz)
    -- 在此逻辑之前，会通过dispatch_message分发消息，缓存消息的发送方、session等信息
    msg = msg or ""
    local tag = session_coroutine_tracetag[running_thread]
    if tag then c.trace(tag, "response") end
    -- 获取缓存的session信息
    local co_session = session_coroutine_id[running_thread]
    session_coroutine_id[running_thread] = nil
    if co_session == 0 then
        if sz ~= nil then
            c.trash(msg, sz)
        end
        return false -- send don't need ret
    end
    -- 获取缓存的发送方信息
    local co_address = session_coroutine_address[running_thread]
    if not co_session then
        error "No session"
    end
    -- 目标服务返回数据给发送方，带上session标识，表示这是该session消息的返回
    local ret = c.send(co_address, skynet.PTYPE_RESPONSE, co_session, msg, sz)
    if ret then
        return true
    elseif ret == false then
        -- If the package is too large, returns false. so we should report error back
        c.send(co_address, skynet.PTYPE_ERROR, co_session, "")
    end
    return false
end
```

可以看到，通过提供发送方与session标识信息，发送方就能够知道哪些消息是该session的返回值了。

这样一来，skynet内部的通信机制，就全部串上了！

## 总结

一不小心写多了点，希望能有助于各位小伙伴加深对服务端以及skynet架构的理解。如果有叙述不当的地方，恳请指正~~~

那么skynet具体要怎么用呢？这一part暂时决定在后面的系列献上~
