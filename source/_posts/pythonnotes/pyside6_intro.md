---
title: 【Python随笔】比PyQt5更先进的pyside6安装和使用方法
date: 2024/08/11 16:12:10
categories:
- Python随笔
tags:
- python
- PyQt5
- pyside6
- Qt
- 工具开发
---

最近因为自研日常开发工具的需求，决定重新拾起PyQt5之类的桌面工具开发技术栈，为啥选用PyQt，一是因为笔者比较精通python，二是因为不需要在外观上做什么特别的东西。经过一番调研，发现当前的PyQt5版本已经过时，用pyside6会更加贴合现在的需求。因此笔者也简单部署了下pyside6的开发环境，通过这篇文章分享一下如何操作。

先强调一点是，所有的资料都可以在[官网](https://doc.qt.io/qtforpython-6/quickstart.html)查到。如果有特别疑问的地方，参考官网，实在不行就stackoverflow或者gpt，也许可以更快解决问题。

<!-- more -->

首先是折腾项目工作区。从个人开发角度，笔者推荐所有的桌面开发项目都放在一个pyside6的工作区，并采用venv来安装pyside6相关库和工具。

pyside6的工具有很多，比如把ui文件转化为python代码的pyside6-uic，以及编辑ui的可视化工具pyside6-designer之类。如果是venv安pyside6的话，这些工具都集成到了`${project_dir}/.venv/bin`下面，有需要的话也可以export到path里，具体作用详细可以参考官网的[这份资料](https://doc.qt.io/qtforpython-6/tools/index.html)。通过这些工具加上一些脚本，就能简单打通ui编辑->ui转码->代码编写->部署发布的开发链路（p.s. 部署发布相关的调研暂时不多）。

代码组织方面，推荐先是把工具类、业务逻辑和ui逻辑几个模块分离开，然后重要一点是，把ui生成代码和实际的window跟widget类给分开来，做到view和model的区分。这样一来是大小层次比较分明，不会出现循环引用的情况，二来是从ui生成的代码，也不会直接影响到已有代码的实现，做改动也是非常方便。以笔者的项目为例，笔者用一个app文件夹来存储所有业务逻辑，通过最外层的main.py驱动app运行：

```python
import app


if __name__ == '__main__':
    app.run()
```

然后在app的__init__.py启动整个项目

```python
APP: Optional[QtWidgets.QApplication] = None


def run():
    global APP
    APP = QtWidgets.QApplication([])

    window = MainWindow()
    window.ensure_center()
    window.show()

    sys.exit(APP.exec())

```

最后在每个ui类实现里面来初始化跟定义界面逻辑：

```python
class MainWindow(QMainWindow):
    def __init__(self):
        super(MainWindow, self).__init__()
        self.ui = Ui_MainWindow()
        self.ui.setupUi(self)

        self._init_actions()
        self._init_widget()

    def _init_actions(self):
        self.ui.actionAbout.triggered.connect(self.show_about)
        self.ui.actionExit.triggered.connect(self.close)

        self.ui.actionSupport.triggered.connect(self.show_support)

    def _init_widget(self):
        # 主动set中心widget，后续可以通过配置化方式灵活设置不同的界面
        self.setCentralWidget(ToolWidget())

    def closeEvent(self, event):  # 关闭窗口时触发
        reply = QMessageBox.question(
            self, '确认', '是否要退出程序？',
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.Yes)
        if reply == QMessageBox.StandardButton.Yes:
            event.accept()
        else:
            event.ignore()
```

以上便是一个简单的pyside6安装和使用方法。后面如果探索到一些新的东西，再拿出来分享～
