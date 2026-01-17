---
title: 【极客日常】Go语言string、int、float、rune、byte等数据类型的转换方法
date: 2021/06/06 21:29:39
categories:
- 极客日常
tags:
- Golang
- strconv
- 数据类型转换
- 编程
- rune
---

golang的数据类型转换是困惑新gopher的一大问题之一。相对于python，golang的数据类型转换可要麻烦的多，而且还不走寻常路地诞生了些新的方法跟名词。因此本文讲解golang常见数据类型string、int、rune等数据类型相互之间的转换方法，给大伙儿避坑。

在讲述方法之前，首先非常有必要讲下go源码对这些数据类型的表述：

<!-- more -->

```go
// string is the set of all strings of 8-bit bytes, conventionally but not
// necessarily representing UTF-8-encoded text. A string may be empty, but
// not nil. Values of string type are immutable.
type string string

// int is a signed integer type that is at least 32 bits in size. It is a
// distinct type, however, and not an alias for, say, int32.
type int int

// int32 is the set of all signed 32-bit integers.
// Range: -2147483648 through 2147483647.
type int32 int32

// uint64 is the set of all unsigned 64-bit integers.
// Range: 0 through 18446744073709551615.
type uint64 uint64

// float32 is the set of all IEEE-754 32-bit floating-point numbers.
type float32 float32

// float64 is the set of all IEEE-754 64-bit floating-point numbers.
type float64 float64

// byte is an alias for uint8 and is equivalent to uint8 in all ways. It is
// used, by convention, to distinguish byte values from 8-bit unsigned
// integer values.
type byte = uint8

// rune is an alias for int32 and is equivalent to int32 in all ways. It is
// used, by convention, to distinguish character values from integer values.
type rune = int32
```

从上面的描述我们可以获得以下信息：

- `int`有符号，至少32位，但并不是`int32`的别称。如果把大于2147483647的数赋值`int`，`int`打出来也是正常的，没有损失精度
- `rune`就是`int32`，实际一般用来表示字符`char`的值。和一般的`char`不一样的是rune的精度比较高= =，并且golang也没有`char`这个内置关键字
- `byte`就是`uint8`，实际一般用来表示二进制数据中比特的值

因此对于`rune`、`byte`这边，就可以当作uint8跟int32相关的转换了，这块的理解就容易得多

首先看字符串`string`到`int`、`float`等数值的转换：

```go
func testStringToDigit() {
    fmt.Println("=============== test string to digit ==================")

    var s string = "1234567"
    var i int
    var i32 int32
    var ui64 uint64

    i, _ = strconv.Atoi(s)
    i64, _ := strconv.ParseInt(s, 10, 32)
    i32 = int32(i64)
    ui64, _ = strconv.ParseUint(s, 10, 64)
    fmt.Printf("string: %s, int: %d, int32:%d, uint64: %d\n",
        s, i, i32, ui64)

    var sf string = "1234512345.12345678901234"
    var f32 float32
    var f64 float64

    f64, _ = strconv.ParseFloat(sf, 64)
    f32In64, _ := strconv.ParseFloat(sf, 32)
    f32 = float32(f32In64)
    fmt.Printf("string: %s, float32: %f, float64: %f\n",
        sf, f32, f64)

    fmt.Println("====================================================")
}
```

`string`到`int`用`strconv.Atoi`方法，而对于其它有bitSize限制的数据，则用`strconv.ParseInt`或者`strconv.ParseFloat`先转换成64位再调精度即可。

然后看数值到`string`的转换：

```go
func testDigitToString() {
    fmt.Println("=============== test digit to string ==================")

    var i int = 12345
    var i32 int32 = -678
    var ui64 uint64 = 901234567890
    var strInt string = fmt.Sprintf("%d", i)
    var strInt32 string = strconv.FormatInt(int64(i32), 10)
    var strUInt64 string = strconv.FormatUint(ui64, 10)
    fmt.Printf("strInt: %s, strInt32: %s, strUInt64: %s\n",
        strInt, strInt32, strUInt64)

    var f32 float32 = 3.1415926
    var f64 float64 = -3.1415926535897
    var strFloat32 string = fmt.Sprintf("%.5f", f32)
    var strFloat64 string = strconv.FormatFloat(f64, 'f', 10, 64)
    fmt.Printf("strFloat32: %s, strFloat64: %s\n", strFloat32, strFloat64)

    fmt.Println("====================================================")
}
```

数值到`string`，最简单粗暴的方法是`fmt.Sprintf`格式化字符串。如果需要精调，则得用`strconv.ParseInt`、`strconv.ParseFloat`等方式。值得一提的是`strconv.ParseFloat`注释了多种格式可供选择，有兴趣的同学可以看源码。

`string`和`rune`、`byte`之类数据的转换，可以如下：

```go
func testStringAndRuneAndByte() {
    fmt.Println("=============== test string & rune & byte ==================")

    var s string = "helloworld"
    var runes []rune = []rune(s)
    var bytes []byte = []byte(s)
    fmt.Printf("string: %s, runes: %v, bytes: %v\n", s, runes, bytes)

    for i, char := range s {
        if i >= 0 {
            fmt.Printf("type of index: %T\n", i) // int
            fmt.Printf("type of char: %T\n", char)  // int32
            fmt.Printf("digit value of char: %d\n", char) // 104
            fmt.Printf("output char: %c\n", char) // h
            fmt.Printf("is equal with rune value: %v\n", 'h' == rune(char)) // true
            fmt.Printf("is equal with byte value: %v\n", 'h' == byte(char)) // true
            // invalid expression -> rune: int32, byte: uint8
            // fmt.Printf("is rune & byte equals: %v\n", rune(char) == byte(char))
            break
        }
    }

    fmt.Println("====================================================")
}

```

用`[]rune`、`[]byte`可直接将`string`变为`charArray`。值得一提的是，遍历`string`时每个`char`字符的类型为`int32`，可用`rune`表示；字符表达式`'h'`可以直接和`rune`、`byte`类型数字用`==`比较。

然后，由于`rune`、`byte`本身就是`int`系，所以这两个和`int`系类型间的转换会非常简单

```go
func testIntAndRuneAndByte() {
    fmt.Println("=============== test int & rune & byte ==================")

    var i int
    var r rune
    var b byte
    var ui8 uint8

    i, r = 123456, 123456
    fmt.Printf("int is equal with rune int: %v\n", int32(i) == r) // true
    b, ui8 = 'a', 'a'
    fmt.Printf("byte char is equal with uint8 char: %v\n", b == ui8) // true
    i = int('a')
    r, b, ui8 = rune(i), byte(i), uint8(i)
    fmt.Printf("int: %c, rune: %c, byte: %c, uint8: %c\n", i, r, b, ui8) // 4 * 'a'

    fmt.Println("====================================================")
}
```

最后一个tips是通用数据类型`interface{}`转特定数据格式的方法，可以这样操作：

```go
func testInterfaceToInt() {
    fmt.Println("=============== test interface to digit ==================")

    var itf interface{}
    itf = 1234567890123456789
    i := itf.(int)

    // cannot convert to int32/int64/float32/float64

    fmt.Printf("interface: %v, int: %d\n", itf, i)

    fmt.Println("====================================================")
}
```

注意`interface{}`赋值了个`int`，如果直接带后缀`.(int32)`这样指定其它数据类型，会直接报错
