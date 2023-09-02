---
title: 【从零单排Golang】第十五话：用sync.Once实现懒加载的用法和坑点
date: 2023/09/03 01:22:03
categories:
- 从零单排Golang
tags:
- Golang
- Once
- 懒加载
- 并发
- 后端开发
---

在使用Golang做后端开发的工程中，我们通常需要声明一些一些配置类或服务单例等在业务逻辑层面较为底层的实例。为了节省内存或是冷启动开销，我们通常采用lazy-load懒加载的方式去初始化这些实例。初始化单例这个行为是一个非常经典的并发处理的案例，比如在java当中，我们可能用到建立双重锁+volatile的方式保证初始化逻辑只被访问一次，并且所有线程最终都可以读取到初始化完成的实例产物。这段经典的代码可以按如下的方式编写：

<!-- more -->

```java
// 参考：https://blog.csdn.net/qq_27489007/article/details/84966680

public class Singleton {
    private volatile static Singleton uniqueSingleton;
 
    private Singleton() {
    }
 
    public Singleton getInstance() {
        if (null == uniqueSingleton) {
            synchronized (Singleton.class) {
                if (null == uniqueSingleton) {
                    uniqueSingleton = new Singleton();
                }
            }
        }
        return uniqueSingleton;
    }
}
```

但在Golang里面，实现懒加载的方式可以简单的多，用内置的sync.Once就能满足。假设我们有一个user单例，需要被1000个线程读取并打印，就可以这样子写：

```go
type User struct {
    Name string `json:"name"`
    Age  int    `json:"age"`
}

var user *User
var userOnce sync.Once

func initUser() {
    user = &User{}
    cfgStr := `{"name":"foobar","age":18}`
    if err := json.Unmarshal([]byte(cfgStr), user); err != nil {
        panic("load user err: " + err.Error())
    }
}

func getUser() *User {
    userOnce.Do(initUser)
    return user
}

func TestSyncOnce(t *testing.T) {
    var wg sync.WaitGroup
    for i := 1; i < 1000; i++ {
        wg.Add(1)
        go func(n int) {
            defer wg.Done()
            curUser := getUser()
            t.Logf("[%d] got user: %+v", n, curUser)
        }(i)
    }
    wg.Wait()
}
```

这段代码里，首先是通过`var userOnce sync.Once`声明了一个`sync.Once`实例，然后在`getUser`当中，我们声明了`userOnce.Do(initUser)`这个操作。假设一个goroutine最先到达这个操作，就会上锁并执行`initUser`，其它goroutine到达之后，得等第一个goroutine执行完`initUser`之后，才会继续`return user`。这样，就能一来保证`initUser`只会执行一次，二来所有goroutine都能够最终读到初始化完成的user单例。

`sync.Once`的工作机理也很简单，通过一个锁和一个flag就能够实现：

```go
func (o *Once) Do(f func()) {
	if atomic.LoadUint32(&o.done) == 0 { // 如果是1表示已经完成了，跳过
		o.doSlow(f)
	}
}

func (o *Once) doSlow(f func()) {
	o.m.Lock() // 只有1个goroutine能拿到锁，其它的等待
	defer o.m.Unlock()
	if o.done == 0 { // 如果还是0表示第一个来的，不是0就表示已经有goroutine做完了
		defer atomic.StoreUint32(&o.done, 1)
		f()
	}
}
```

最后也需要注意，`sync.Once`使用上面有一个坑点，不能也不需要像java一样为单例提前做nil判断。比如下面一段代码是有问题的：

```go
func initUser() {
    user = &User{} // 先给一个zero-value实例
    cfgStr := `{"name":"foobar","age":18}` // 然后加载json内容，完成初始化
    if err := json.Unmarshal([]byte(cfgStr), user); err != nil {
        panic("load user err: " + err.Error())
    }
}

func getUser() *User {
    if user == nil {
        userOnce.Do(initUser)
    }
    return user
}
```

由于Golang没有volatile关键字，不能控制单例在内存的可见性，那么多goroutine并发时，就有可能出现这样的执行时序：

- `goroutine-A`过了`getUser`的`user == nil`判断，进入到了`initUser`逻辑，走到了`cfgStr := XXX`一行
- 此时切换到`goroutine-B`，因为`goroutine-A`在`initUser`已经走过了`user = &User{}`一行，所以跳过了`user == nil`判断，直接返回没有完全初始化的`user`实例，然后一直往下运行，就没切回给`goroutine-A`

这样的结果，就导致有goroutine拿到未初始化完成的实例往后运行，后面就出问题了。所以实战当中需要留意，用`sync.Once`时，不能也不需要加这些nil判断，就能满足懒加载单例/配置之类的逻辑。
