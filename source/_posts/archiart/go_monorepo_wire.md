---
title: 【架构艺术】Go大仓monorepo中使用wire做依赖注入的经验
date: 2025/04/04 17:22:40
categories:
- 架构艺术
tags:
- 架构
- 后端开发
- monorepo
- wire
- Golang
---

在[先前的文章](https://utmhikari.blog.csdn.net/article/details/146134024)当中，笔者分享了一套简洁的go微服务monorepo代码架构的实现，主要解决中小团队协同开发微服务集群的代码架构组织问题。但是在实际代码开发过程中，怎么组织不同的业务服务service实例，就成了比较棘手的问题。

为什么会出现这样的场景？首先，不同的业务服务可能会用到相同的底层服务，比如DB、缓存、MQ以及三方Client等等。其次，一个底层服务实例可能会在多个业务服务复用，一个业务服务又可能成为另外一个业务服务的依赖。因此这样下来，不同服务实例之间就存在错综复杂的联系，用代码组织起来就比较困难了。

幸运的是，我们拥有wire工具去做go对象的依赖注入，这样就可以用简单的代码实现解决上述问题。在[以前的wire文章](https://utmhikari.blog.csdn.net/article/details/128161738)当中，也简单提到了wire对于微服务框架的作用，但讲解的不算特别精要。所以今天这篇文章，笔者就分享下在go大仓的场景下，怎么用wire去解决service实例依赖问题的，以及怎样才是更加恰当的打开方式。

首先我们要知道wire工具对外暴露了什么能力，有以下一些：

<!-- more -->

- NewSet：声明一组Provider，Provider可以是对象的Constructor/Factory，也可以是其他Provider
- Value：把一个特定的对象给Provide出去
- InterfaceValue：把一个特定的interface对象给Provide出去（比如context.Context）
- Struct：把一个struct给Provide出去，同时可指定具体要被更底层注入对象的字段
- Bind：一般用于去声明某一个特定的interface对象需要某一个特定的struct实例来实现
- FieldsOf：把单个struct的某些特定的字段给Provide出去

对于大仓的每一个微服务来讲，我们可以用到这些能力来描述不同服务service实例的依赖，这样就可以用wire一次性把我们所有service实例的初始化代码给生成出来，并且可以提前检查依赖的正确性，从而runtime的时候就不会出现哪个底层服务实例有nil异常的情况。

具体怎么做，首先我们在biz下面一般有handler、service、config等子目录，我们可以加一个子目录ioc，用来存放wire依赖注入的内容。

- ioc.go：执行初始化逻辑的入口，存放暴露给handler层的所有上层service实例。
- wire.go：声明所有service实例的依赖关系，可后续生成包含初始化代码的wire_gen.go。

ioc.go里面这样写：

```go
type IOC struct {
    User service.IUserService // 建议对外暴露Interface类型的service
    Task service.ITaskService
    // ...其他service
    DB dal.DB // interface or pointer
    Cache cache.Cache // interface or pointer
}

var Instances *IOC

func Init() {
    instances, err := initIOC()
    if err != nil {
        panic(err)
    }
    Instances = instances
}
```

这样handler层就可以通过ioc.Instances.XXX直接获取service实例调用对应业务，然后业务的实现代码就放到service层具体的user或者task目录，层次结构就比较清晰了。

我们假设user的实现依赖db服务，task的实现依赖user、db和cache服务，那么UserService和TaskService的代码实现可以是这样：

```go
type IUserService interface {
    GetUser(ctx context.Context, userID int64) (*User, error)
}

type UserServiceImpl struct {
    DB dal.DB
}

// GetUser 从DB拿
func (u *UserServiceImpl) GetUser(ctx context.Context, userID int64) (*User, error) {
    return DB.GetUser(ctx, userID)
}

// user实现上需要db服务
func NewUserService(db dal.DB) IUserService {
    return &UserServiceImpl{
        DB: db,
    }
}

type ITaskService interface {
    CreateTask(ctx context.Context, userID int64) (int64, error)
    GetTask(ctx context.Context, taskID int64) (*Task, error)
}

type TaskServiceImpl struct {
    DB dal.DB
    Cache cache.Cache
    User IUserService
}

// CreateTask 拿user信息存DB
func (t *TaskServiceImpl) CreateTask(ctx context.Context, userID int64) (int64, error) {
    userInfo, err := t.User.GetUser(ctx, userID)
    if err != nil {
        return 0, err
    }
    task := &Task{
        Creator: userInfo.Name,
    }
    return DB.CreateTask(ctx, task)
}

// GetTask 先拿缓存再拿DB
func (t *TaskServiceImpl) GetTask(ctx context.Context, taskID int64) (*Task, error) {
    taskInfo := new(Task)
    var err error
    cacheKey := fmt.Sprintf("task:%d", taskID)
    if err = t.Cache.Load(ctx, cacheKey, taskInfo); err == nil {
        return taskInfo, nil
    }
    taskInfo, err = DB.GetTask(ctx, taskID)
    if err != nil {
        return nil, err
    }
    t.Cache.Save(ctx, cacheKey, taskInfo)
    return taskInfo, nil
}

// task实现上需要db、cache和user服务
func NewTaskService(db dal.DB, cache cache.Cache, user IUserService) ITaskService {
    return &TaskServiceImpl{
        DB: db,
        Cache: cache,
        User: IUserService,
    }
}

```

以上面wire为前提，接下来wire.go就可以这样写，从而简单声明所有可能出现的服务实例，打平依赖顺序：

```go
var ctx = context.Background() // 初始化的ctx一般就是background

// 底层依赖
var (
    ctxSet = wire.InterfaceValue(new(context.Context), ctx)
    // 如果有静态DB配置的话，先initConfig然后再ioc.Init
    // cfg模块主动暴露方法拿对应DB配置，这样比如相同类型DB有多套配置也可以自由provide出来
    dbSet = wire.NewSet(dal.NewDB, cfg.GetDB)
    cacheSet = wire.NewSet(cache.NewCache, cfg.GetCache)
)

// 总集
var providerSet = wire.NewSet(
    ctxSet,
    dbSet,
    cacheSet,
    userService.NewUserService,
    taskService.NewTaskService, // task依赖user，写下面
    wire.Struct(new(IOC), "*") // instances放在最下面
)

// 初始化方法
func initIOC() (*IOC, error) {
    panic(wire.Build(providerSet))
    return new(IOC), nil
}
```

这样wire.Build过后，所有服务实例的初始化代码就生成了，我们在每个微服务的main里面调用ioc.go里面的Init，就可以把所有服务实例生成出来，ezpz！
