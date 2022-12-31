---
title: 【从零单排Golang】第七话：反射模块reflect使用方式探索
date: 2023/01/01 02:16:48
categories:
- 从零单排Golang
tags:
- Golang
- 反射
- reflect
- interface
- json
---

`Golang`的反射功能，在很多场景都会用到，最基础的莫过于`rpc`、`orm`跟`json`的编解码，更复杂的可能会到做另外一门语言的虚拟机。通过反射模块，我们可以在编程语言的`runtime`运行时期间去访问内部产生对象的信息。了解反射模块的实现，对我们了解`Golang`对象机制本身，也是莫大的帮助。

今天，恰逢阳康+新年，就决定来探究一下`Golang`的反射模块——`reflect`。

从最基础的开始，`reflect`模块，以获取整数对象的类型信息为例，我们可以这么用：

<!-- more -->

```go
func TestReflect_Integer(t *testing.T) {
    i := 1
    v := reflect.ValueOf(i)
    vKind := v.Kind()
    vType := v.Type()
    t.Logf("i kind: %+v\n", vKind)
    t.Logf("i type: %+v\n", vType)

    itf := v.Interface()
    j, ok := itf.(int)
    t.Logf("j val: %+v\n", j)
    if !ok || j != i {
        t.Fatalf("i != j")
    }
}
```

`reflect.ValueOf`的入参是`interface{}`类型，新版本也叫做`any`，得到的返回值是`reflect.Value`类型的对象，可以认为是对原对象的一个描述性质的对象（元对象，233）。`reflect.Value`包含几个成员：

- `typ`：原对象类型的元信息
- `ptr`：指向原对象值的原生指针
- `flag`：原对象类型的正整数标识

当调用`Kind`跟`Type`接口，四舍五入就是获取了`reflect.Value`对象的`flag`跟`typ`成员实例了。

要把`reflect.Value`转换回原对象，首先需要通过`Interface`方法转化成`interface{}`类型的对象，再通过`.(int)`强转逻辑去转化成原对象。但这里需要注意下，如果真需要用到`reflect`反射功能且涉及到一些看似要“强转”的场景，可能是没有必要真的在代码中强转回特定类型对象的。好比`rpc`的调用，实质是在声明接口方法的基础上，把接口方法变成`reflect.Value`对象，再用`Func.Call`方法做函数调用。这里，也给个`example`：

假设我们定义`User`结构体，内部嵌套`UserInfo`结构体，均有`json`标注，然后定义了`ToString`跟`Response`两个方法，大概长这样：

```go
type UserInfo struct {
    Desc string `json:"desc"`
    City string `json:"city" desc:"the city of user"`
}

type User struct {
    ID   int       `json:"id"`
    Name string    `json:"name"`
    Info *UserInfo `json:"info"`
}

func (u *User) ToString() string {
    return fmt.Sprintf("[%d]%s", u.ID, u.Name)
}

func (u *User) Response(from string, msg string) string {
    return fmt.Sprintf("User %s received msg %s from <%s>", u.ToString(), msg, from)
}
```

那么比如`Response`方法，实际上也能够这样调用：

```go
func TestReflect_Method(t *testing.T) {
    u := &User{1, "jack", nil}
    uPtr := reflect.ValueOf(u)
    // MethodByName：获取特定名字的Method
    meth, ok := uPtr.Type().MethodByName("Response")
    if !ok {
        t.Fatalf("no method named Response")
    }
    t.Logf("meth Response: %+v\n", meth)

    methType := meth.Type
    // 入参3个：User实例、from、msg
    if methType.NumIn() != 3 {
        t.Fatalf("invalid NumIn %d, expected %d", methType.NumIn(), 3)
    }
    // 返回值1个：response string
    if methType.NumOut() != 1 {
        t.Fatalf("invalid NumOut %d, expected %d", methType.NumOut(), 1)
    }
    // 通过Func.Call得到返回值list
    from, msg := reflect.ValueOf("client"), reflect.ValueOf("ping")
    rets := meth.Func.Call([]reflect.Value{uPtr, from, msg})
    if len(rets) != 1 {
        t.Fatalf("invalid num rets %d, expected %d", len(rets), 1)
    }
    // 返回1个string对象
    respVal := rets[0]
    if respVal.Type() != reflect.TypeOf("") {
        t.Fatalf("invalid ret type %v, expected %s", respVal.Type(), "STRING")
    }
    resp, ok := respVal.Interface().(string)
    if !ok {
        t.Fatalf("ret value cannot be converted to string")
    }
    t.Logf("resp: %s\n", resp)
}
```

通过`MethodByName`方法，可以定位到一个对象下的某个名字的方法实例，通过对方法实例调用`Func.Call`，就能实际实现对方法的调用，得到返回值列表。

涉及到指针对象的反射值，可以通过`reflect.Indirect(反射值)`或者`反射值.Elem()`的方式，获取到指针指向实例的反射值。`example`代码如下，因为上面我们定义`ToString`和`Response`方法绑定的是指针对象，在这样的条件下，指针指向实例的反射值就拿不到`ToString`方法了，打印便知：

```go
func TestReflect_Pointer(t *testing.T) {
    u := &User{1, "jack", nil}
    vPtr := reflect.ValueOf(u)
    vPtrKind := vPtr.Kind()
    vPtrType := vPtr.Type()
    t.Logf("ptr kind: %+v\n", vPtrKind)
    t.Logf("ptr type: %+v\n", vPtrType)
    meth, ok := vPtrType.MethodByName("ToString")
    t.Logf("ptr meth ToString: %+v (%+v)\n", meth, ok)

    vVal := reflect.Indirect(vPtr)
    // vVal := vPtr.Elem()
    vValKind := vVal.Kind()
    vValType := vVal.Type()
    t.Logf("val kind: %+v\n", vValKind)
    t.Logf("val type: %+v\n", vValType)
    meth, ok = vValType.MethodByName("ToString")
    t.Logf("val meth ToString: %+v (%+v)\n", meth, ok)
}
```

再进一步来看，对于`slice`、`map`这类对象，也可以通过`reflect.Value`内置的一些方法，访问到内部的对象。假设我们要实现`slice`跟`map`的复制操作，用纯反射的方式也可以实现：

```go
func TestReflect_CopySliceAndMap(t *testing.T) {
    mp := map[string]int{
        "jack": 1,
        "tom":  2,
    }
    sl := []int{1, 1, 2, 3, 5, 8}
    vals := []reflect.Value{reflect.ValueOf(mp), reflect.ValueOf(sl)}
    var copyVals []reflect.Value

    for _, val := range vals {
        var copyVal reflect.Value
        switch val.Kind() {
        case reflect.Map:
            // MakeMap：创建map实例
            copyVal = reflect.MakeMap(val.Type())
            // MapRange：获取map对象的Iterator
            iter := val.MapRange()
            for iter.Next() {
                copyVal.SetMapIndex(iter.Key(), iter.Value())
            }
        case reflect.Slice:
            // AppendSlice：在一个slice的基础上extend另一个slice
            copyVal = reflect.AppendSlice(
                reflect.MakeSlice(val.Type(), 0, val.Len()),
                val)
        }
        copyVals = append(copyVals, copyVal)
    }

    // 通过DeepEqual方法，可以做值的相等性比较
    for _, val := range copyVals {
        switch val.Kind() {
        case reflect.Map:
            if val.Len() != len(mp) {
                t.Fatalf("invalid map length %d, expected %d", val.Len(), len(mp))
            }
            copyVal, ok := val.Interface().(map[string]int)
            if !ok {
                t.Fatalf("map convert failed")
            }
            t.Logf("copied map: %+v", copyVal)
            for k, v := range mp {
                copyV, ok := copyVal[k]
                if !ok || !reflect.DeepEqual(v, copyV) {
                    t.Fatalf("copy value of key %s failed, expected %d, actual %d", k, v, copyV)
                }
            }
        case reflect.Slice:
            if val.Len() != len(sl) {
                t.Fatalf("invalid slice length %d, expected %d", val.Len(), len(sl))
            }
            copyVal, ok := val.Interface().([]int)
            if !ok {
                t.Fatalf("slice convert failed")
            }
            t.Logf("copied slice: %+v", copyVal)
            if !reflect.DeepEqual(copyVal, sl) {
                t.Fatalf("slice not equal")
            }
        }
    }
}
```

最后，也看一下`reflect`作用到`struct`定义的一些使用方法，这里就需要看`reflect.Value.Type()`返回的`Type`实例有什么功能了。对于`Type`实例来讲，我们可以遍历所有结构体字段定义，甚至是访问标注信息，比如`json`、`orm`的编解码，就极度依赖这些字段的标注信息。这里的实现，也给个`example`：

```go
func TestReflect_Struct(t *testing.T) {
    st := reflect.ValueOf(&User{
        ID:   9,
        Name: "Ronaldo",
        Info: &UserInfo{
            Desc: "SC",
            City: "Madrid",
        },
    }).Elem().Type()
    // 多少个字段
    numField := st.NumField()
    t.Logf("num fields: %d", numField)
    // 一个个字段遍历，输出字段名字、数据类型、json标注
    for i := 0; i < numField; i++ {
        field := st.Field(i)
        t.Logf("field %d -> name: %s, type: %v, json: %s",
            i+1,
            field.Name,
            field.Type,
            field.Tag.Get("json"))
    }
    // 嵌套的字段，用FieldByIndex可以定位到
    cityField := st.FieldByIndex([]int{2, 1})
    // 按照上面UserInfo.City的定义，拿取desc标注信息
    cityFieldDesc, ok := cityField.Tag.Lookup("desc")
    if !ok {
        t.Fatalf("cannot find city field desc")
    }
    t.Logf("CityField -> name: %s, type: %v, desc: %s",
        cityField.Name,
        cityField.Type,
        cityFieldDesc)
}
```

可以看到，我们可以很方便拿到结构体的定义信息，更加深层嵌套的定义信息也都能拿到。可以说，太灵活了！
