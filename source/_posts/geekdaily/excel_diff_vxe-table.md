---
title: 【极客日常】用vxe-table展示excel-diff的结果
date: 2021/05/01 16:50:18
categories:
- 极客日常
tags:
- 前端开发
- Vue
- vxe-table
- 游戏测试
- 测试开发
---

excel-differ是游戏测试常用的测试工具。在有些业务场景下，excel-diff的结果可能需要通过web展示。Vue技术栈下的[vxe-table](https://gitee.com/xuliangzhan_admin/vxe-table)表格组件能够支持大量数据的展示，因此可以用vxe-table展示excel-diff的结果。

excel-diff的算法本身，[先前的文章](https://utmhikari.top/2021/03/06/testlife/table_check/)已有讲解，在结果展示上会按file->sheet来分。为了让结果展示更加人性化，需要对表格的样式进行区分。在[vxe-table的api列表](https://xuliangzhan_admin.gitee.io/vxe-table/v4/table/api)中，我们可以通过`cell-class-name`的回调函数指定每个单元格的样式。针对excel-diff的结果可以这样设计样式：

<!-- more -->

- 新增行/列：背景浅绿色
- 删除行/列：背景浅红色
- 重复行/列：背景浅灰色
- 移动行/列：背景浅橙色
- 修改单元格：背景浅黄色，字体红色

用户在实际查看excel-diff结果时，通常需要自动滚动到对应的位置。vxe-table提供了如下api支持滚动：

- `scrollToRow(row, fieldOrColumn)`：滚动到对应的行或列（注意field不是展示出来的表头）
- `scrollToColumn(fieldOrColumn)`：滚动到对应的列

获取行、列的实例，可以用这些方法：

- `getRowById(rowid)`：根据行的唯一主键（string）获取行
- `getColumns()`：获取columns列表
- `getColumnById(colid)`：根据列的唯一主键（string）获取列
- `getColumnByField(field)`：根据列的字段名获取列

需要注意的是，滚动后，默认滚动到的行会置顶，列会放到最左边，观感不是很好。因此可以做以下的优化：

- 当处在较为靠左的列，直接滚动到最左边
- 当处在较为靠右的列，直接滚动到最右边
- 其他情况下，滚动到前面隔2个的列
- 滚动到的行也可做类似处理，这样大部分选中数据都会显示在上面靠左的位置，基本满足观感需求

针对大的表，可能会出现性能问题。性能的优化tips有以下几个：

- 针对excel数据本身，过滤空表头、空行等无效数据，保证只有有效数据参与diff计算
- 表格需要设定`scroll-x`与`scroll-y`虚拟滚动设置，尽量一次性不渲染太多内容
- 用Object.freeze冻结excel数据、diff结果相关的object，因为这些object本身就应当是immutable的，用Object.freeze可[避免vue做底层各属性的getter/setter绑定](https://www.cnblogs.com/goloving/p/13969685.html)
- 对于每个单元格取`cell-class-name`，也需要预先computed + Object.freeze一个缓存data，使得回调函数判断class-name直接可以在其中取字段来判断，这样逻辑复杂度会小
- 数据预处理中，如果要用到循环逻辑，可考虑普通的for循环代替forEach
