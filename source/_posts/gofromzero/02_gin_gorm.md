---
title: 【从零单排Golang】第二话：初探服务端CRUD，gin+gorm黄金搭档
date: 2019/08/04 18:38:41
categories:
- 从零单排Golang
tags:
- Golang
- 后端开发
- gin
- gorm
- CRUD
---

## 前言

[Github传送门](https://github.com/utmhikari/gofromzero)

学一门新语言，如果太专注于语法，那肯定学的不够快。如果有一定的需求目标，带着这个目标去学习一门新语言，这样才能学得快。

工作中写后端的时间比例不在少数，而且传闻Go也因其适用于服务端而著名。在Go社区中最为火热的服务端框架跟数据库抽象ORM层当属[gin](https://github.com/gin-gonic/gin)跟[gorm](https://github.com/jinzhu/gorm)了，因此本期单排的目标便是用gin+gorm打一个简易的框架，实现基本CRUD的目标。走你~

## 准备工作

在[第一话](https://utmhikari.github.io/2019/07/20/gofromzero/01_first_code/)中已经大致了解了Go项目的生成，故本次gin+gorm的搭建也以此为基础。

服务端领域的各种术语在不同的场景跟技术栈下有不同的含义。但总体来讲，一个简单的服务端App都会有以下的层次：

- 校验层：预处理请求，校验请求是否合法（大小、字段、cors、oauth之类），并判断是否拦截。通常也被称作中间层middleware
- 控制层：处理合法请求的起点——收集整理相应服务模块的结果，判断请求是否合理，决定返回的数据，遵循宽进严出原则。一般叫做Controller，gin里面叫做handler。
- 业务层：处理真实的业务逻辑，通过和数据层以及各个业务模块的交互从而校验并构建业务数据，交由控制层决策，一般可称之为service
- 数据层：抽象持久化数据（数据库）到代码层面并提供一系列交互访问的方法，ORM与DAO层都算在内

基于以上结构，大致构建了以下的目录结构：

<!-- more -->

- root
  - database 数据层
    - main.go 封装gorm
    - xxx.go 表xxx
  - handler 控制层
    - base.go 封装基本返回方法
    - xxx.go 模块xxx控制器
  - service 业务层
    - xxx 业务模块xxx（防止相互引用，用文件夹隔开）
      - abc.go 模块xxx的abc业务
  - app.go 服务端app
  - router.go 服务端路由

本次demo没有弄校验层(router里设置各种middleware)，直接从handler开始干拉~

## gorm封装

gorm实现了不同数据库对Go对象的映射。gorm本身提供了默认的表Model（id、增删改时间），但实际还是建议自行封装一层，以增加可控性。

这里以mysql交互为例，实现了一个封装例子。

```go
// database/main.go
package database

type DBModel struct {
    *gorm.Model
    // You can add your own model components here
}

// DB database instance
var DBInstance *gorm.DB

// InitDB initialize DB
func InitDB() {
    log.Println("Initializing database...")
    // 从docker hub pull下来就好了= =
    db, err := gorm.Open("mysql", "root:123456@tcp(localhost:32773)/gofromzero?charset=utf8mb4&parseTime=True&loc=Local")
    if err != nil {
        panic(err)
    }
    DBInstance = db
}
```

假使我们创建一个User表，我们可以在另一个go文件内引用DBModel跟DBInstance，从而定义数据交互逻辑

```go
// database/user.go
package database

// User表的结构
type User struct {
    *DBModel
    Name string `json:"name"`
    Age uint `json:"age"`
}

type userDAO struct {}

// UserDAO user dao
var UserDAO userDAO

// Create create a user record
func (*userDAO) Create(user User) error {
    DBInstance.AutoMigrate(&User{})
    return DBInstance.Create(&user).Error
}

// First get the first record of user
func (*userDAO) First() (User, error) {
    var user User
    err := DBInstance.First(&user).Error
    return user, err
}

// Update update user record
func (*userDAO) Update(user User) error {
    return DBInstance.Model(&User{}).Updates(&user).Error
}

// Delete set all to delete state
func (*userDAO) Delete() error {
    return DBInstance.Delete(&User{}).Error
}
```

这样在外部要跟User表交互的话，直接用`UserDAO`就可以完成需求了

## gin服务搭建

有了对gorm的进一步封装，我们就不需过多担心数据获取的问题。现在我们可以关注gin的写法。

首先建议封装一些常用的返回方法，什么success、error之类，有助于减少码量。

```go
// handler/base.go
package handler

func Success(c *gin.Context, data interface{}) {
    c.JSON(http.StatusOK, gin.H{
        "data": data,
    })
}

func Error(c *gin.Context, err error, code int) {
    c.JSON(code, gin.H{
        "err": err.Error(),
    })
}
```

而后在user模块的handler下，实现控制器逻辑：

```go
// handler/user.go
package handler

import (
    "github.com/gin-gonic/gin"
    service "github.com/gofromzero/ii/service/user"
    "net/http"
)

type user struct{}

// User instance of user controller
var User user

// Create create a user
func (*user) Create(c *gin.Context) {
    var userForm service.Form
    bindErr := c.ShouldBindJSON(&userForm)
    if bindErr != nil {
        Error(c, bindErr, http.StatusForbidden)
        return
    }
    createErr := service.Create(userForm)
    if createErr != nil{
        Error(c, createErr, http.StatusBadRequest)
        return
    }
    Success(c, "Create user successfully!")
}

// 下略，CRUD
```

我们可以看到我们通过一个文件夹定义了user业务层的模块。业务层代码如下：

```go
// service/user/crud.go
package user

type Form struct {
    Name string `json:"name"`
    Age uint `json:"age"`
}

// Create create user on form
func Create(form Form) error {
    return database.UserDAO.Create(database.User{
        Name: form.Name,
        Age: form.Age,
    })
}

// First get first user from database
func First() (database.User, error) {
    return database.UserDAO.First()
}

// Update update user records
func Update(form Form) error {
    return database.UserDAO.Update(database.User{
        Name: form.Name,
        Age: form.Age,
    })
}

// Delete delete user records
func Delete() error {
    return database.UserDAO.Delete()
}
```

在这个demo中，业务层的代码看起来有点多余，基本是纯粹调用UserDAO的方法。但实际项目写大的话，其实还会涉及到和其它模块的交互。因此，这一层的独立是有必要的。

最后，在路由中调用`handler.User`，我们就能很轻松地注册user模块的控制器：

```go
// router.go

// Router gin router
func Router() *gin.Engine {
    log.Println("Registering routers...")
    r := gin.Default()
    api := r.Group("/api")
    v1 := api.Group("/v1")
    {
        user := v1.Group("/user")
        {
            user.POST("", handler.User.Create)
            user.GET("", handler.User.Get)
            user.PUT("", handler.User.Update)
            user.DELETE("", handler.User.Delete)
        }
    }
    return r
}
```

启动App实例：

```go
// app.go

// StartGin start gin server
func StartGin() {
    database.InitDB()
    defer database.CloseDB()
    router := Router()
    s := &http.Server{
        Addr:    ":8080",
        Handler: router,
    }
    err := s.ListenAndServe()
    if err != nil {
        panic(err)
    }
}
```

试试看吧~

## 总结

Go在整体印象上真的很严格，甚至比Java还严格。这part的代码写起来真心不如JS轻松，但通过这些换来代码健壮性与服务性能增益，是很值得的。

这次项目架构的设计也仅是抛砖引玉，对gorm以及gin还没有更加深入的探究。以后可得加油~
