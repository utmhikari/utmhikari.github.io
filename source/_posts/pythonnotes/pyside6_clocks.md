---
title: 【Python随笔】pyside6绘制表盘和数字时钟的方法
date: 2024/10/13 13:28:01
categories:
- Python随笔
tags:
- python
- pyside6
- 工具开发
- 渲染
- 桌面应用
---

最近在重玩pyside/pyqt桌面开发的内容，计划做一些日常工具来自用，顺带练练手。正好刚遇到一个问题是画时钟（表盘+数字），查了很多资料都稍微调试了下才最终解决，本文即分享一下解决方法。

首先是数字时钟。由于pyside6本身有QLCDNumber控件的支持，所以绘制起来比较容易，官网也给了一个[例子](https://doc.qt.io/qtforpython-6/examples/example_widgets_widgets_digitalclock.html)。笔者自己则在这个基础上做了下修改，代码如下：

<!-- more -->

```python
import sys

from PySide6.QtCore import QTime, QTimer, Slot
from PySide6.QtWidgets import QApplication, QLCDNumber


class DigitalClock(QLCDNumber):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSegmentStyle(QLCDNumber.Flat) # 设置显示样式，可以看哪个比较美观
        self.setDigitCount(8)

        # 定时器每秒更新
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.show_time)
        self.timer.start(1000)

        self.show_time()

    @Slot()
    def show_time(self):
        time = QTime.currentTime()
        text = time.toString("hh:mm:ss") # 直接格式化显示即可

        # Blinking effect，视情况使用
        # if (time.second() % 2) == 0:
        #     text = text.replace(":", " ")

        self.display(text)


if __name__ == "__main__": # 测试代码
    app = QApplication(sys.argv)
    clock = DigitalClock()
    clock.show()
    sys.exit(app.exec())
```

而表盘时钟则相对难一些，主要是需要拿到一个比较好的效果。经过一番寻找，在[这个例子](https://doc.qt.io/qtforpython-6/examples/example_gui_analogclock.html)里面展示的效果比较不错。笔者也是在这个基础上做了一点调整，详细代码如下：

```python
from PySide6 import QtCore, QtGui, QtWidgets
from PySide6.QtCore import QPoint, QTimer, QTime, Qt
from PySide6.QtGui import QGuiApplication, QPainter, QPalette, QPolygon

class AnalogClock(QtWidgets.QWidget):
    def __init__(self, parent=None):
        super(AnalogClock, self).__init__(parent)

        # 每1s更新绘图
        self._timer = QtCore.QTimer(self)
        self._timer.timeout.connect(self.update)
        self._timer.start(1000)

        # 绘制时针、分针、秒针，粗细形状可以调整QPoint参数
        self._hour_hand = QPolygon([
            QPoint(4, 14),
            QPoint(-4, 14),
            QPoint(-3, -55),
            QPoint(3, -55)
        ])
        self._minute_hand = QPolygon([
            QPoint(4, 14),
            QPoint(-4, 14),
            QPoint(-3, -85),
            QPoint(3, -85)
        ])
        self._seconds_hand = QPolygon([
            QPoint(1, 14),
            QPoint(-1, 14),
            QPoint(-1, -90),
            QPoint(1, -90)
        ])

        # 调色板，调整时针、分针、秒针和背景色
        palette = qApp.palette()
        self._background_color = palette.color(QPalette.ColorRole.Base)
        self._hour_color = palette.color(QPalette.ColorRole.Text)
        self._minute_color = palette.color(QPalette.ColorRole.Text)
        self._seconds_color = palette.color(QPalette.ColorRole.Accent)

    def paintEvent(self, event):  # 重载paintEvent函数来画图
        width = self.width()
        height = self.height()
        side = min(width, height)

        with QPainter(self) as painter:  # painter有前后处理，with一下
            # 绘制背景
            painter.fillRect(0, 0, width, height, self._background_color)
            painter.setRenderHint(QPainter.Antialiasing)
            painter.translate(width / 2, height / 2)
            painter.scale(side / 200.0, side / 200.0)

            time = QTime.currentTime()

            # 通过setBrush设置绘图颜色，绘制时针
            painter.setPen(Qt.NoPen)
            painter.setBrush(self._hour_color)
            painter.save()
            painter.rotate(30.0 * ((time.hour() + time.minute() / 60.0)))
            painter.drawConvexPolygon(self._hour_hand)
            painter.restore()

            # 绘制小时的12点
            for _ in range(0, 12):
                painter.drawRect(73, -3, 16, 6)
                painter.rotate(30.0)

            # 绘制分针
            painter.setBrush(self._minute_color)
            painter.save()
            painter.rotate(6.0 * time.minute())
            painter.drawConvexPolygon(self._minute_hand)
            painter.restore()

            # 绘制秒针，带一个针头
            painter.setBrush(self._seconds_color)
            painter.save()
            painter.rotate(6.0 * time.second())
            painter.drawConvexPolygon(self._seconds_hand)
            painter.drawEllipse(-3, -3, 6, 6)
            painter.drawEllipse(-5, -68, 10, 10)
            painter.restore()

            # 绘制分钟的60分
            painter.setPen(self._minute_color)
            for _ in range(0, 60):
                painter.drawLine(92, 0, 96, 0)
                painter.rotate(6.0)
```
