---
title: 【测试人生】python的excel库——openpyxl的用法
date: 2021/07/11 00:03:07
categories:
- 测试人生
tags:
- python
- openpyxl
- excel
- 测试工具
- 测试开发
---

## 前言

在测试工具的开发过程中，可能会遇到需要生成excel文件的需求。笔者在自研excel-diff工具的过程中，也同样接到了需要生成excel文件来展示每个sheet的diff数据。每个包含diff的sheet需要生成1个excel文件，每个文件分成3个sheet，2个sheet用于展示sheet原先的数据与修改后的数据，1个sheet用于描述性统计和超链接每个diff的情况。要生成这样的excel文件，不用专门的excel库是不行的。基于python的技术栈，经过一番调研，笔者采用openpyxl作为生成excel的库，并且顺利完成了需求。

学习openpyxl可以直接从[官方文档](https://openpyxl.readthedocs.io/en/stable/)入手。一些基本操作如下：

<!-- more -->

## 基础workbook与sheet操作

启动一个excel实例，直接构造`Workbook`实例即可：`wb = Workbook`

`Workbook`实例默认会带一个sheet，名称即为Sheet，可以直接通过`ws = wb.worksheets[0]`获取到这个默认的sheet。如果要改标题，可以直接用`ws.title = 'xxx'`来执行。

为sheet添加数据有多种方法：

- `ws.append(list_data)`，添加一行数据
- `ws.cell(row, col, value)`，为某行某列（都从1开始算）的单元格赋一个值

创建sheet，通过`wb.create_sheet(title='xxx')`接口即可实现；通过`ws = wb.active`，可以设置某个sheet为默认打开展示的。

获取某行、某列以及单元格数据，可以通过`ws.iter_rows(row_idx, row_idx)`、`ws.iter_cols(col_idx, col_idx)`、`ws.cell(row_idx, col_idx)`获取，其中行、列索引均从1开始算。但如果只是要获取行、列实例，比如要调行列样式的话，需要通过`ws.row_dimensions[row_idx]`、`ws.col_dimensions[get_column_letter(col_idx)]`获取，其中`get_column_letter`是`openpyxl.util`中，通过列索引获得对应字母（A~Z，AA~AZ之类）的方法

通过`load_workbook`、`save_workbook`接口，可以读取或存储为excel文件。需要注意的是，这两个操作在大数据量表的情况下会有时间开销。

## 样式设置

调整excel表格样式，建议用`NamedStyle`定义各个不同的样式。一个`NamedStyle`可以应用单个单元格可支持的所有样式，包括：

- font：字体
- fill：背景颜色
- border：边框
- alignment：排版（水平垂直居中之类）
- etc

单元格样式需要遍历每个单元格设置，比如：

```python
ns = NamedStyle(name='test_style')
ns.font = Font(bold=True)  # 粗体
ns.alignment = Alignment(wrapText=True)  # 自动换行
wb.add_named_style(ns)

for row_idx in range(2, 6):
    for col_idx in range(3, 7):
        ws.cell(row_idx, col_idx).style = 'test_style'
```

行、列样式，通过上述从`row_dimensions`、`col_dimensions`获取的实例，可以直接赋予`width`、`height`之类的行列样式属性

如果要冻结行列，需要通过设置`ws.freeze_panes`为特定值，这个值是这样规定的。比如`ws.freeze_panes = 'D5'`，则表示冻结D列之前的A~C列，同时冻结5行之前的1~4行。以此类推，如果`ws.freeze_panes = 'A1'`，那就是没有冻结的行列了。

## 总结

openpyxl内部涵盖的功能非常丰富，笔者所讲述的只是冰山一角。有兴趣的同学可以尽情探索openpyxl的官方文档以及源代码，有问题也可直接google查阅~
