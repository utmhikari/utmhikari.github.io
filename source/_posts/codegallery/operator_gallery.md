---
title: 【代码艺廊】operator-gallery：纯vibe的operator管理工具
date: 2026/04/08 19:09:45
categories:
- 代码艺廊
tags:
- Kubernetes
- operator-gallery
- Vibe Coding
- Golang
- Docker
---

近期AI编程的新概念层出不穷，从最简单的Code Completion，到NEXT预测，再到现在什么Vibe Coding、OpenClaw，外加Spec Coding、Harness Engineering等Agent工程名词，可以说随着LLM的能力增强，不考虑业务架构，纯考虑编程本身，AI几乎已经可以替代所有人类，对于程序员而言，以前要做亲自编码，现在则需要转化为一个管理者的角色，指导AI完成程序员的工作目的。

为了体验AI编程的强大，近期笔者借助AI Native的开发工具，通过纯Vibe Coding的方式，开发一个基于kubebuilder的operator管理工具。kubebuilder本身提供的命令和功能已经很丰富了，但还是免不了一些小问题，比如在国内某些镜像和依赖拉不下来，或者开发多个operator没有一个工作区做统一管理，这些问题都可以由一个operator-gallery工具去做解决。

换言之，operator-gallery的职责是封装kubebuilder，端到端地处理operator的构建、部署和卸载流程，这样开发者只需要专注在types和controller的实现就可以。

<!-- more -->

相关的代码已经放到[operator-gallery](https://github.com/utmhikari/operator-gallery)这个GitHub仓库当中，有兴趣的读者可以随时fork做二次开发，vibe出GUI等更多实用的功能。

同时也聊聊Vibe Coding吧，从笔者比较粗浅的vibe经验来看，因为Agent上下文有限，所以还是保持一个好记性不如烂笔头的原则，鼓励AI频繁做开发经验沉淀，提升自身在项目研发的拟合度。关于Skill方面笔者目前还没有过多的尝试，后续有机会也再探索一下。
