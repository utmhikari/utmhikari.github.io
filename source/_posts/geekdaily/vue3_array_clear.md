---
title: 【极客日常】vue3中实现Array数组清空的方法
date: 2022/06/17 20:59:28
categories:
- 极客日常
tags:
- vue3
- nodejs
- Array
- state
- reactive
---

近期由于工作原因，开始了解`vue3`的内容。`vue3`相对于`vue2`采用了组合式的描述，原来的写法是：

```javascript
export default {
    name: 'HelloWorld',
    data: {
        return {
            a: 1,
            b: 2,
        }
    },
    mounted() {
        this.a = 3
    }
    methods: {
        onConfirm() {
            console.log(this.a)
        }
    }
}
```

而到了`vue3`，提倡的写法变成了：

<!-- more -->

```javascript
import { ref, reactive, toRefs } from 'vue'

export default {
    name: 'HelloWorld',
    setup() {
        const a = ref(1)
        const state = reactive({
            b: 2
        })
        
        onMounted(() => {
            a.value = 3
        })
        const onConfirm = () => {
            console.log(this.a)
        }

        return {
            a,
            onConfirm,
            ...toRefs(state)
        }
    }
}
```

也就是说不需要把`methods`、`data`、`computed`还有各类钩子区分开，script的内容都能通过一个`setup`函数来组织，这样代码会有更强的可读性，实际开发时候也不会上下来回切。

初次接触这种写法的时候就遇到了一个问题，好比说有个`table`绑定了属性`dataList`，是个那么`dataList`在`setup`里处理逻辑应该是怎样的呢？

这里有两种方法，一种方法是用`ref`修饰，这样这个`dataList`实例如果调用`push`之类的方法，其变化不会被侦测到，但可以用新的一个数组全量替换原来的`dataList`；另一种方法是用`reactive`修饰，这样一些类方法调用时候能`hook`到，使得对应的页面内容产生变化，但如果全量替换，是没法感知到的。

综合以上两点，实际场景下，还是推荐第三种方法：

```javascript
import { reactive } from 'vue'

export default {
    name: 'HelloWorld',
    setup() {
        const abcState = reactive({
            abcDataList: []
        })
        const defState = reactive({
            defDataList: []
        })
        return {
            abcState,
            defState
        }
    }
}
```

先定义各类`state`，可以认为是划分功能模块所`model`的数据，再把实际的数据属性放到`state`里，最后组合在一起。这样列表类型的数据只能全量替换，但有一个好处，就是通过不同`state`的组合，代码逻辑更加清晰了，有点像以前`store`的设计，同时也能规避列表类型数据更新后同步渲染到页面的问题。

以上就是`vue3`中实现Array数组清空的解决方式。
