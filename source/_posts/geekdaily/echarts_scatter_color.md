---
title: 【极客日常】在Vue用echarts画带不同颜色点的散点图
date: 2021/09/16 23:27:20
categories:
- 极客日常
tags:
- vue
- echarts
- 散点图
- scatter3D
- visualMap
---

在vue技术栈下做图表需求，[echarts](https://echarts.apache.org/zh/index.html)是一个非常棒的选择，提供了非常多种多样的图标示例以及非常复杂强大的API。由于笔者近期工作内容中需要分析采样点的分布情况，因此自然而然接触到了echarts的[3D散点图](https://echarts.apache.org/examples/zh/index.html#chart-type-scatter3D)。在笔者的需求中，需要对不同点进行分类，并按特定的颜色显示出来。经过一番踩坑，了解到了echarts在实现这方面的机制。

echarts绘图/刷新只需要通过`setOption`接口即可实现。在各种options中，[visualMap视觉映射组件](https://echarts.apache.org/handbook/zh/concepts/visual-map)能够根据数据在特定维度上的值，指定对应点的视觉属性（比如颜色、透明度、图元大小等等）。

要用到visualMap特性，需要import相关组件：

<!-- more -->

```js
import { VisualMapComponent } from 'echarts/components'
echarts.use(VisualMapComponent)
```

记得如果要用到其余的一些tooltip之类的组件，也得加上这些import声明。

假设我们数据每项包含X、Y、Z坐标以及一个表示颜色类别的项，我们需要首先设定visualMap如下（也可以参考官方的诸多例子）：

```js
option = {
  visualMap: [
    {
      min: 0,
      max: 1000,
      dimension: 4,
      inRange: {
        color: ['#000000', '#aabbcc', '#ffffff']
      }
    }
    //    ...
  ]
};
```

这表示上色的时候，会读取数据第5个维度（index/dimension = 4）的值，然后根据值寻找对应的颜色。值的范围是0~1000，也就是说我们数据里第5个维度值为0的话，就是`#000000`，取1000就是`#ffffff`，然后取中间500的话就是`#aabbcc`了

因此我们可以转换下数据，添加颜色对应的整数值：

```js
const colorTagToIntMap = {
    COLOR_A: 0,
    COLOR_B: 500,
    COLOR_C: 1000
}
const newData = data.map(item => {
    const colorInt = colorTagToIntMap[item.colorTag]
    return [
        item.X,
        item.Y,
        item.Z,
        item.colorTag,
        colorTagToInt
    ]
})
```

然后在对应[dataset](https://echarts.apache.org/handbook/zh/concepts/dataset)中，设置dimension为表头，设置data为上述的newData，就ok了。
