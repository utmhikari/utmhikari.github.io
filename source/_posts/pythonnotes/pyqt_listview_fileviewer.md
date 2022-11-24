---
title: 【Python随笔】PyQt5的QListView兼容左键双击事件和右键上下文菜单的方法
date: 2022/10/02 03:28:15
categories:
- Python随笔
tags:
- PyQt5
- QListView
- Qt
- 上下文菜单
- MVC
---

近期笔者因工作原因，需要做一个安卓手机的文件浏览功能，集成在笔者以前用`PyQt5`做的一个的工具当中。文件浏览功能大概做成这样：

- 一个列表界面，列出某个目录下的所有文件名（不区分文件和文件夹）
- 双击某个文件名，尝试进入这个文件名代表的文件夹（文件的情况会失败）
- 右键某个文件名，弹出上下文菜单，可以进入这个文件名对应的文件夹，也可以复制路径到其他的输入框

其中，文件列表选型用了`QListView`组件，但在实现兼容双击进入文件夹+右键菜单功能时，稍微踩了下坑。为了解决这个问题，笔者在网上查阅了许多资料，最后找到一种解决方法，决定记录于本文当中。

首先需要了解，`Qt`对于`QListView`这类数据容器组件，是遵循`MVC`的设计模式的。`QListView`数据的初始化，方法是这样的：

<!-- more -->

```python
data = ['1', '2', '3']
model = QStringListModel()
model.setStringList(data)
listview = QListView()
listview.setModel(model)
```

可以看到，是`data -> model -> view`这样的关系呈现。

要让`listview`同时支持双击和右键事件，常见的想法是用`doubleClicked`、`clicked`之类的`signal`去`connect`对应的事件委托。但这里有一个误区：`clicked`有`connect`事件委托这种情况下，不论在`listview`里单击鼠标左键或者单击右键，都能触发鼠标单击事件，而如果同时`connect`了`doubleClicked`的委托，`doubleClicked`的委托会无法执行。这样的话，就无法同时满足左键双击和右键上下文菜单功能。

看似这个问题无法解决，实际上`Qt`还是给开发者留下了一个后门——`QWidget`本身有一个`setContextMenuPolicy`接口去设置上下文菜单策略，而这个上下文菜单就是右键触发的。因此，我们可以通过绑定`doubleClicked`事件委托，同时`setContextMenuPolicy`为自定义菜单模式`CustomContextMenu`，并绑定`customContextMenuRequested`这个`signal`到一个自动弹出上下文菜单的方法，就可以事件左键双击事件和右键上下文菜单的兼容了。

代码样例如下：

```python
def on_double_clicked(idx):
    # idx为QModelIndex类型，通过row方法获取数据索引值
    print(f'triggered double-click -> {data[idx.row()]}')


def on_trigger_menu_action():
    # 通过selectedIndexes方法可以获得点中的所有项
    selected_indexes = listview.selectedIndexes()
    if len(selected_indexes) > 0:
        data_idx = selected_indexes[0].row()
        print(f'triggered context menu -> {data[data_idx]}')


def on_custom_context_menu_requested(pos):
    ctx_menu = QtGui.QMenu()
    menu_action = popMenu.addAction('打印信息')
    menu_action.triggered.connect(on_trigger_menu_action)
    ctx_menu.exec_(QtGui.QCursor.pos())  # 由当前鼠标位置弹出菜单


listview.doubleClicked.connect(on_double_clicked)
listview.setContextMenuPolicy(Qt.CustomContextMenu)
listview.customContextMenuRequested.connect(on_custom_context_menu_requested)
```

在`doubleClicked`的场景下，可以通过传参的`QModelIndex`实例直接获取数据的索引值，从而拿到数据；在`customContextMenuRequested`的场景下，可以通过`listview`的`selectedIndexes`获取所有选中项的`QModelIndex`，进而也是通过`row`接口，就可以知道哪个下标的数据被选中了。
