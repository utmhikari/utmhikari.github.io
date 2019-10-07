---
title: 【极客日常】hexo+NexT博客自定义代码高亮主题配色CSS
date: 2019/10/07 01:40:29
categories:
- 极客日常
tags:
- hexo
- NexT
- 代码高亮
- styl
- CSS
---

用hexo+NexT搭建博客的同学或许会遇到一个问题：默认的代码配色只有[Tomorrow Theme](https://github.com/chriskempson/tomorrow-theme)五种，如果想要自己的代码配色，应当如何自定义呢？

其实也是可以的。在NexT的`source/css/highlight/theme.styl`中，我们就可以看到几种主题的具体配色：

```styl
$highlight_theme = hexo-config("highlight_theme")

if $highlight_theme == "normal"
  $highlight-background   = #f7f7f7
  $highlight-current-line = #efefef
  $highlight-selection    = #d6d6d6
  $highlight-foreground   = #4d4d4c
  $highlight-comment      = #8e908c
  $highlight-red          = #c82829
  $highlight-orange       = #f5871f
  $highlight-yellow       = #eab700
  $highlight-green        = #718c00
  $highlight-aqua         = #3e999f
  $highlight-blue         = #4271ae
  $highlight-purple       = #8959a8
  $highlight-gutter       = {
    color: #869194,
    bg-color: #eff2f3
  }

if $highlight_theme == "night"
  $highlight-background   = #1d1f21
  $highlight-current-line = #282a2e
  $highlight-selection    = #373b41
  $highlight-foreground   = #c5c8c6
  $highlight-comment      = #969896
  $highlight-red          = #cc6666
  $highlight-orange       = #de935f
  $highlight-yellow       = #f0c674
  $highlight-green        = #b5bd68
  $highlight-aqua         = #8abeb7
  $highlight-blue         = #81a2be
  $highlight-purple       = #b294bb
  $highlight-gutter       = {
    color: lighten($highlight-background, 50%),
    bg-color: darken($highlight-background, 100%)
  }

...
```

我们可以看到其实如果要增加一个自定义主题的话，其实加一段if跟其配色，然后在配置里配置theme的关键词就好了。那么自己配色的话应该怎样参考呢？我们可以在`source/css/highlight/highlight.styl`中找到答案：

<!-- more -->

```styl
pre {

  .comment { color: $highlight-comment; }

  .variable
  .attribute
  .constant
  .tag
  .name
  .regexp
  .ruby
  .xml .tag .title
  .xml .pi
  .xml .doctype
  .html .doctype
  .css .id
  .css .class
  .css .pseudo {
    color: $highlight-red;
  }

  .number
  .preprocessor
  .built_in
  .builtin-name
  .literal
  .params
  .constant
  .command {
    color: $highlight-orange;
  }

  .constant {
    color: $highlight-constant;
  }

  .ruby .class .title
  .css .rules .attribute
  .string
  .symbol
  .value
  .inheritance
  .header
  .ruby .symbol
  .xml .cdata
  .special
  .formula {
    color: $highlight-green;
  }

  .title
  .css .hexcolor {
    color: $highlight-aqua;
  }

  .function
  .python .decorator
  .python .title
  .ruby .function .title
  .ruby .title .keyword
  .perl .sub
  .javascript .title
  .coffeescript .title {
    color: $highlight-blue;
  }

  .keyword
  .javascript .function {
    color: $highlight-purple;
  }
}
```

我们在这段css中可以看到不同的代码块的不同配色，对照该css所示配置颜色即可。当然若有细节需求，更改上面代码块的css也是ok的。

比如笔者采用经典的`solarized light`配色，就可以在`source/css/highlight/theme.styl`加上一段：

```styl
if $highlight_theme == "solarized light"
  $highlight-background   = #FDF6E3
  $highlight-constant     = #00FF00
  $highlight-current-line = #FDF6E3
  $highlight-selection    = #ECE7D5
  $highlight-foreground   = #657A81
  $highlight-comment      = #93A1A1
  $highlight-red          = #D30102
  $highlight-orange       = #657A81
  $highlight-yellow       = #657A81
  $highlight-green        = #2AA198
  $highlight-aqua         = #657A81
  $highlight-blue         = #657A81
  $highlight-purple       = #B58900
  $highlight-gutter       = {
    color: #586E75
    bg-color: #FDF6E3
  }
```

然后在NexT的`_config.yml`中应用该配置：

```yaml
# Code Highlight theme
# Available values: normal | night | night eighties | night blue | night bright
# https://github.com/chriskempson/tomorrow-theme
highlight_theme: solarized light
```

就ok了
