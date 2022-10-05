---
title: 【GitHub探索】ebook-boilerplate——批量转markdown为PDF和电子书
date: 2022/10/05 16:16:16
categories:
- GitHub探索
tags:
- ebook-boilerplate
- tex
- pandoc
- markdown
- pdf
---

正值十一假期，近期准备把自己的`python`笔记精编整理，做一个`pdf`电子书。在调研如何把多个`markdown`文档转化为单个`pdf`的时候，试了很多种方法。最后找到了最佳方案，也就是本文的主角，由`phodal`前辈整理的电子书生成项目[ebook-boilerplate](https://github.com/phodal/ebook-boilerplate)。这个项目不仅支持批量转`markdown`为`pdf`，而且还支持转成`ebook`等多种格式。

使用这个项目的时候，也踩了一些坑，需要做一些额外的配置。以笔者的场景为例，电子书生成环境是`Ubuntu22`，需要转化一堆中文的`markdown`。`clone`了这个项目之后，除了`ebook-boilerplate`本身`README.md`里描述的内容之外，实际还需要留意以下环节：

<!-- more -->

第一块是`pandoc`跟`texlive`的环境，最好是官网下载最新的版本，`apt`里面的版本已经过时了。尤其是`texlive`，`apt`拿到的版本很多宏库都没有，得要用官网最新的`install`脚本才会自动把各种`package`都装上。

然后是生成`pdf`的操作里，需要指定一种支持中文的`tex-engine`，笔者是选择了`xelatex`。需要在`makefile`的`pandoc`生成`pdf`那块做修改：

```text
pdf: markdown
	pandoc -s $(filename).md -o $(filename).pdf \
		--title-prefix $(title) \
		--listings -H listings-setup.tex \
		--template=template/template.tex \
		--pdf-engine=xelatex \  # 加这一行，声明pdf-engine
		--toc
```

之后，`markdown`生成`pdf`的步骤，实际是把所有`markdown`内容按文件名顺序（可以用数字标识组织一下）拼接在一起，然后用`toc`按照`markdown`的标题文本（`h1`、`h2`之类）生成目录，最后再生成`pdf`。这里有一个问题，就是我们每一章都要分页，而在`markdown`里标识分页的`html`标签`<div STYLE="page-break-after: always;"></div>`在`tex-engine`下面，是没法出分页的效果的。这种情况下的解决方案是：把这个标签换成`\newpage`，这样`tex-engine`就能识别了。也就是说，你的`md`文件的内容应该是：

```text
# 1.1 xxx.md

# 上面忽略你的markdown正文

\newpage
```

再之后，我们可以修改`listings-setup.tex`以及`template/template.tex`里的内容，去修改代码高亮跟正文的排版参数。以笔者的观感为例，这里面的内容编辑了以下几个部分：

- 代码高亮，即`listings-setup`，`basicstyle`设置字号为`\small`
- `template.tex`里，取消对于中文刊物习惯的设置，正文字号为`9pt`，行距调整为`1.1`。
- `xelatex`下，中文字体为`Noto Sans CJK SC`，默认字体为`Helvetica`。当然，如果你喜欢衬线`Serif`字体，也都得调整成衬线的形式。

最后就是各种调试勘误，生成最后的文档了。

当然，一开始所说的，笔者精心整理的`python`笔记，现在也已出炉。各位读者可以阅读[这篇文章](https://www.bilibili.com/read/cv18933862)以获取资源。
