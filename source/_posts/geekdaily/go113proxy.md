---
title: 【极客日常】解决国内go1.13的go mod无法安装依赖的问题
date: 2019/10/07 01:40:29
categories:
- 极客日常
tags:
- Golang
- GOPROXY
- go mod
- GOSUMDB
- go env
---

在[从零单排Golang第一话](https://utmhikari.github.io/2019/07/20/gofromzero/firstcode/)中讲到了Golang的基础开发环境配置，其中讲到了Go的依赖管理方面，提及了以后的趋势会采用官方的go mod进行管理。关于这一块，现在有了更加简单的方法。

最新的Go1.13中已经将go mod列为默认的包管理方法，但国内用户go mod vendor时还是有可能会出错，这是因为在go get时会检查哈希值，需要访问官方的sumdb。由于众所周知的不可抗因素，sumdb没法直接访问，这样就会造成下载依赖失败。解决的方法也很简单，只需要一行终端命令即可：

```sh
go env -w GOPROXY=https://goproxy.cn,direct
```

如果采用idea+Go插件开发的话需要注意，idea可能会托管环境变量，这个时候需要进入`settings, languages & frameworks, go, go modules`里，设置proxy为`https://goproxy.cn,direct`，就ok了。
