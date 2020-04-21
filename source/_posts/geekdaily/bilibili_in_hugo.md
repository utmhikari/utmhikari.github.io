---
title: 【极客日常】在hugo博客中利用shortcode嵌入bilibili视频
date: 2020/04/21 16:07:57
categories:
- 极客日常
tags:
- hugo
- 个人博客
- bilibili
- shortcode
- iframe
---

[hugo](https://gohugo.io/)是当前热门的个人博客框架之一，和hexo同样是markdown文件跟博客帖子一一对应。有些同学想利用hugo制作个人视频博客，但发现在hugo博客中不支持直接在markdown里输入iframe标签，从而没有办法将其它网站的视频（比如b站）嵌进来。这种情况下，我们可以采用hugo内置的[shortcode](https://gohugo.io/content-management/shortcodes/)机制完成这个需求。

我们参考的文章是[create your own shortcodes](https://gohugo.io/templates/shortcode-templates/)，在这个文档中介绍了自定义shortcode从而快速渲染网页的方法，并且举了youtube以及vimeo的例子。照葫芦画瓢，我们也可以定义b站的shortcode。

我们首先在`layouts/shortcodes`目录下创建`bilibili.html`，然后填充内容如下：

<!-- more -->

```html
<iframe
    src="//player.bilibili.com/player.html?bvid={{.Get 0 }}&page={{ if .Get 1 }}{{.Get 1}}{{ else }}1{{end}}"
    scrolling="no"
    height="768px"
    width="1024px"
    frameborder="no"
    framespacing="0"
    allowfullscreen="true"
>
</iframe>
```

整个iframe是基于b站分享链接模板的。对于用户而言，主要关心bv号跟page（一个bv可能是个视频列表，有好几part）。在`bilibili.html`中，定义了唯一的bv号作为query，而后page默认为1，用户可以自行指定。

写好了`bilibili.html`中，在markdown里嵌入视频的话，用以下形式写就ok了：

```text
{{< bilibili BV1RE411b71v >}}
```

如果需要指定part，比如要看大逃脱第一季第3回，这样写就ok了：

```text
{{< bilibili BV18t41187Bx 3 >}}
```
