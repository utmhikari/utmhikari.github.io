---
title: 【极客日常】Win10更改IDEA（Jetbrains全家桶）的插件和配置路径
date: 2020/10/06 22:54:09
categories:
- 极客日常
tags:
- Intellij IDEA
- Jetbrains
- IDE
- Win10
- idea.properties
---

Jetbrains家的IDE，默认安装之后，配置和插件都存储在系统特定的文件夹中，如果是Windows系统的话，就会在用户文件夹存储。这样就滋生了一个问题：随着插件等安装的越来越多，系统盘也会占掉一些空间，这个时候就有了转移默认插件与配置路径的需求。今天就以IDEA为例讲述一下如何操作。

<!-- more -->

首先了解下默认存储的位置。Win10的话，IDEA可能在这里：`C:\Users\用户名\AppData\Roaming\JetBrains`。如果是AndroidStudio，则可能在这里：`C:\Users\用户名\.AndroidStudio4.0`。在这个目录里面深度浏览，应该能够看到有一个文件夹下存储了`config`以及`system`文件夹，这里便存储了插件、IDE配置等内容。

而后退出idea，先在某个地方新建文件夹，将`config`与`system`目录剪切进去（本文新建`D:\.IDEA`文件夹为例）。然后进入IDEA的安装目录，在其`bin`目录下有一个`idea.properties`文件，用记事本、notepad++之类的软件打开，修改其中内容：

```text
#---------------------------------------------------------------------
# Uncomment this option if you want to customize path to IDE config folder. Make sure you're using forward slashes.
#---------------------------------------------------------------------
# 默认下面这行是会注释掉的，现在取消注释，配置为新的config目录。注意路径分隔符是正斜杠，不是反斜杠
idea.config.path=D:/.IDEA/config

#---------------------------------------------------------------------
# Uncomment this option if you want to customize path to IDE system folder. Make sure you're using forward slashes.
#---------------------------------------------------------------------
# 同样，取消下面一行的注释，配置为新的system目录
idea.system.path=D:/.IDEA/system


# 下面两个插件、日志的配置不用去掉注释，是跟随config和system配置走的

#---------------------------------------------------------------------
# Uncomment this option if you want to customize path to user installed plugins folder. Make sure you're using forward slashes.
#---------------------------------------------------------------------
# idea.plugins.path=${idea.config.path}/plugins

#---------------------------------------------------------------------
# Uncomment this option if you want to customize path to IDE logs folder. Make sure you're using forward slashes.
#---------------------------------------------------------------------
# idea.log.path=${idea.system.path}/log
```

之后再重新打开IDEA，应该新的配置都生效了。可以装一个插件试试看？应该不会在系统盘里装了。这个方法，理论上J家桶的IDE都可以用上，试试看吧~

如果IDEA有大版本更新，注意在更新的时候，不要选择replace掉原来的`idea.properties`文件，而是ignore。不然又要重新来一遍了。
