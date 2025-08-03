---
title: 【GitHub探索】Prompt开发评测平台CozeLoop踩坑体验
date: 2025/08/03 14:35:50
categories:
- GitHub探索
tags:
- AI
- Agent
- Coze
- DDD
- Prompt
---

接续[先前CozeStudio的文章](https://utmhikari.top/2025/08/03/githubdiscovery/coze_studio/)，CozeLoop相对于CozeStudio，更加专注于Prompt Engineering，打磨整个Agent Prompt的效果。因此，本篇文章也分享一下笔者使用CozeLoop的体验，源码可以从[这个Repo](https://github.com/coze-dev/coze-loop)里面拉取。

<!-- more -->

CozeLoop也采用DDD的范式，但和CozeStudio稍微有区别。CozeLoop分为api、modules和infra三大层，但在modules里面就包含了评测集、评测实验、LLM、trace等模块，每个模块下面就有比较清晰的app、domain、infra的划分了，所以本质上还是符合DDD的范式的。

部署方面比较坑，CozeLoop没有CozeStudio那样开源的效果好，笔者折腾了很久才在本地跑起来服务。主要遇到了几个问题：

- 主机用mac，但服务需要部署在linux/amd64的服务中，需要在Dockerfile以及各个安装脚本里面做兼容，比如指定架构platform、取消CGO等，防止指令集不兼容；
- MySQL缺少默认DB，这个需要查下issue然后新增个sql+替换entrypoint.sh来解决；
- cozeloop-broker起不来，这个发现是笔者自己的colima核数太少，加大核数调大sleep解决了。

开发方面，CozeLoop先是提供了一个Prompt调试界面，可以看到Prompt的运行结果，也有对比功能看不同模型不同Prompt对同一个问题的效果。然后评测方面，提供了评测集/评估器管理以及实验任务等功能。从评估器角度来看，评估器的Prompt需要有评测input、预期output以及实际output的输入，而被评估的Prompt必须得设置一个变量，引用评测集的input，才能让Prompt了解到每一次要评测哪个输入（也就是说，写一个面向评测的Prompt）。实验的过程也是submit任务，创建任务记录后，每条评测就开始自己在MQ里面Loop，推进结果了。由于注入变量这个事情官方文档讲的也不详细，也踩了一些坑，实际调试的时候，也可以根据每个测试的Trace结果，来判断实验是否按照预期执行。
