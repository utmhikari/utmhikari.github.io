---
title: 【极客日常】一种解决redis源码编译时jemalloc报No such file or directory错误的方法
date: 2021/10/19 23:32:16
categories:
- 极客日常
tags:
- redis
- 编译
- jemalloc
- 远程开发
- linux
---

在用源码编译redis的过程中，可能会报jemalloc出错，提示No such file or directory的问题，导致构建不能继续。一种常见的，在网上流传的方法是[调整MALLOC参数为libc](https://stackoverflow.com/questions/47088171/error-jemalloc-jemalloc-h-no-such-file-or-directory-when-making-redis)，但这并不是唯一解，不能一概而论。

以笔者的例子，笔者采用windows装CLion并用Remote Development连接linux虚拟机的方式来编译redis源码，版本为6.2.6，在构建的过程中也报了jemalloc出No such file or directory的问题。在笔者的场景下，仔细查看日志，会出现许多`Permission Denied`的字样，这说明有许多脚本没有执行权限。经过一番研究，执行下面俩操作之后，`distclean`一下，就能成功再次编译redis。

- 在`src`目录下，`chmod +x ./mkreleasehdr.sh`，增加这个脚本的执行权限
- 在`deps`目录下，`chmod -R 777 jemalloc`，把jemalloc目录下所有文件权限都提上来

暂时研究到的是这些，可以试试看。
