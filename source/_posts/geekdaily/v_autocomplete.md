---
title: 【极客日常】写一个基于vuetify的v-autocomplete的自定义组件
date: 2020/02/16 14:59:57
categories:
- 极客日常
tags:
- vuetify
- v-autocomplete
- vue
- v-model
- 前端开发
---

[Vuetify](https://vuetifyjs.com/zh-Hans/)是Vue的一套前端组件框架，基于Material Design设计，界面较为整洁。最近由于项目需要开始入手，但在写自定义`v-autocomplete`组件的时候却踩了许多坑。因此本文果断记录一下踩坑的过程。

首先新上手vue的话肯定耳边都会萦绕着“双向绑定”一词，用的最多的属性就是`v-model`了。但是我们参考[官方文档](https://cn.vuejs.org/v2/guide/forms.html)可以发现`v-model`只是语法糖，除了绑定默认组件的值（比如`select`元素是`value`，而`checkbox`元素是`checked`）之外，还会绑定监听用户输入事件（比如`text`元素是`input`，而`radio`元素是`change`）。因此要用`v-model`的话需要关注相应的元素是否本身就支持语法糖。我们在[v-autocomplete官方文档](https://vuetifyjs.com/zh-Hans/components/autocompletes)中可以发现，其扩展了`v-select`组件，因此如果用自定义组件包一层的话，一般主要关心的是怎样传递最终选择的value，就可以了。

比如要做一个异步检索items的`v-autocomplete`组件，我们可以用如下的方式自定义：

其中template如下：

<!-- more -->

```html
<template>
    <v-autocomplete>
        :v-model="select"
        :items="items"
        :loading="loading"
        :search-input.sync="search"
        item-text="text"
        item-value="value"
    </v-autocomplete>
</template>
```

然后script如下：

```javascript
export default {
    // 略过其它属性
    data() {
        return {
            items: [],
            loading: false,
            currentSearchValue: '',
            search: null,
            select: null
        }
    },
    watch: {
        select(val) {
            // 触发changeVal事件，更改select到的item的value
            this.$emit('changeVal', val)
        },
        search(val) {
            this.currentValue = val
            // 注意保持缓存的items，不要加清空items的逻辑，否则先前传出去的item的value（select）也没了
            this.handleSearch(val)
        }
    },
    methods: {
        handleSearch(v) {
            var _this = this
            setTimeout(() => {
                if (!_this.currentValue === v) {
                    return
                }
                _this.loading = true
                // 下面是自定义的检索items的逻辑
                asyncSearch().then((resp) => {
                    if (resp.code === 200 && _this.currentValue === v) {
                        _this.items = resp.data.map(d => ({
                            ...d,
                            text: d.textPart,  // 显示的文本
                            value: d.valuePart,  // 真正要传出去的值
                        }))
                    }
                    _this.loading = false
                }).catch(() => {
                    _this.loading = false
                })
            }, 200)
        }
    }
}
```

这样在接受组件值的那一端，假设我们自定义组件叫`CustomVAutoComplete`的话。只需要写：

```html
<CustomVAutoComplete @changeVal="handleValChange" />
```

```javascript
export default {
    // 略过其它属性
    data() {
        return {
            autoCompleteVal: '',
        }
    },
    methods: {
        handleValChange(v) {
            this.autoCompleteVal = v
        }
    }
}
```

就可以了
