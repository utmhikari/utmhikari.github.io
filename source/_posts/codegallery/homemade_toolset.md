---
title: 【代码艺廊】pyside6桌面应用范例：homemade-toolset
date: 2025/04/04 16:23:10
categories:
- 代码艺廊
tags:
- python
- pyside6
- homemade-toolset
- 桌面应用
- 工具开发
---

在研发测试日常工作中，通常会遇到很多琐碎的事情，占用我们工作的时间和精力，从而导致我们不能把大部分的注意力放在主要的工作上面。为了解决这个问题，除了加人之外，我们通常会开发一些日常用的效率工具，比如以pyqt、pyside为主体的桌面应用，一键化我们的日常工作，从而解放我们很多处理琐碎事情的精力，让我们有更多精力打磨主业，创造更好的工作成绩。

因此，本文就分享下笔者在24年下半年调研学习pyside6的一些成果，把自己做的小应用[homemade-toolset](https://github.com/utmhikari/homemade-toolset)开源出来，供各位有需要的同学参考学习。

整个项目包含时间转换工具、JSON工具以及类似Postman的Request工具，采用python3.11和pyside6开发，目录结构如下：

<!-- more -->

- app：应用内容
  - __init__.py：app初始化逻辑
  - service：业务逻辑
  - util：工具类
  - view：前端逻辑
    - component：可复用的ui组件
    - ui：通过pyside6-designer生成的ui代码
    - worker：后台异步/并发的任务类
    - XXX.py：主页面逻辑
- cfg：配置文件
- etc：静态资源
  - ui：pyside6-designer的ui文件
  - script：研发脚本
    - deploy.sh：app打包，workdir为项目根目录
    - uic.py：pyside6-designer的ui文件转py文件的脚本，workdir为项目根目录
- main.py：程序入口
- pysidedeploy.spec
- README.md：项目介绍

使用方法上，直接配venv下好requirements执行main即可，编译打包用的是etc/script/deploy.sh，里面执行pyside6-deploy做打包，可以在pysidedeploy.spec做打包配置。ui文件在etc/ui目录下，可以用pyside6-designer去设计，然后统一通过etc/script/uic.py脚本转为py文件。

具体里面的代码实现，可以参考下面的文章了解详情：

- [【Python随笔】比PyQt5更先进的pyside6安装和使用方法](https://utmhikari.blog.csdn.net/article/details/141107150)
- [【Python随笔】pyside6绘制表盘和数字时钟的方法](https://utmhikari.blog.csdn.net/article/details/142898055)
- [【Python随笔】如何用pyside6开发并部署简单的postman工具](https://utmhikari.blog.csdn.net/article/details/144635170)
- [【Python随笔】将requests实例转换成curl语句](https://utmhikari.blog.csdn.net/article/details/143463615)

