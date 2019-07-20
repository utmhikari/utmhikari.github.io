---
title: 【测试人生】MTSC2019参会见闻感悟
date: 2019/07/01 23:11:36
categories:
- 测试人生
tags:
- 测试
- MTSC
- QA
- 质量管理
- TaaS
---

“测试人生”第一篇文章，献给2019年的移动测试开发大会MTSC。这一次，非常荣幸能够来到北京国际会议中心参会，一睹国内质量保障工作的现状与未来的发展趋势。

在学校期间，我也参与过一些小型的学术会议，但并不如今年的MTSC这样声势浩大。工作一年以来参与的第一个讨论会，已然是全国顶会。借这个机会，能够了解到业内排头企业在质量保障业务上的解决方案，对于自己在业务理解上会颇有帮助。本次议程中，除了参与第一天主会场之外，第二天游戏测试专场也全程参与，收获颇丰，感悟良多，一言难尽。

<!-- more -->

测试流程全自动化是质量管理的终极梦想，但是现实并不完美，比如游戏领域，在交付频繁、以及场景逻辑复杂的限制下，必须要有一定手工测试的成分。所以所谓测试流程自动化，应该怎样界定最为合适？其实我们会发现自动化的一大目标是促进生产力，在必须赋予人力研发的背景下，如何快速验证产品的质量，监控、定位&解决问题，同时预测问题、避免以前的问题产生呢？带着这些有关于生产效率增强方面的问题，我们才会想到以接口自动化、devops为首的一些列测试流程技术。因此追求自动化不是关键，关键是发掘研发过程中的效率痛点。比如百度的自动构建权重量化可以及时评估交付质量，蚂蚁的卡分支管理能够显著避免版本commit/push问题，这些都是非常不错的点子。

从整个产品线跟测试岗位的职责上的关系来看，测试人员在多数情况下会担任一个服务者的角色。比如我自己，作为测试开发，职责不仅是解决技术问题，探究底层疯狂码触之类，还需要推动自己的产品，与业务线沟通跟进，了解业务线使用产品的方式与收益，并借此机会继续挖掘潜在需求。因此我套用了一个缩写，提出TaaS的概念——Test as a Service，来形容测试人员、尤其是测试开发人员的工作。

从TaaS的角度而言，测试开发对于业务线的服务是两个方向的。第一种是由外而内型，较多以平台+插件的方式存在，工作类似外包的性质，比如WeTest跟UWA。这一类测试业务更加关注于已构建/待交付产品的综合质量评估，注重C/S性能、安全、静态扫描，或是针对特定框架/引擎的精准测试方面。第二种是随波逐流型，与业务线耦合度较高，主要针对研发期未交付生产版本前的质量控制，像接口自动化/回归、覆盖率、commit hook、协议测试之类的针对性效率工具，更易在项目研发早期、未交付生产版本时进行推动。不管是哪一种情况，提升研发效率，满足项目需求，优先级一直得排第一。

这一届大会同样涌现了许多智能科技/AI测试方面的主题，狭义地讲，也就是机器学习技术的应用。比如今年的腾讯，在游戏UI自动化测试方面取得了很大的进展，实现了手游CF的Bot。腾讯的这一场演讲吸引了小讲室两倍椅子数的观众，同行们对高新技术应用于质量管理业务颇有兴致，但不可否认的是，腾讯在发展Turing Lab的背后，是其多年的游戏研发管理经验以及质量管理体系/技术基建，才能够支持他们在高新技术方面的研究，并且另一方面，要往AI测试技术进行应用，技术深度是其次，而AI能够解决业务中的哪些痛点，如何获取足量有价值的数据集，如何打通整个AI测试流程，才是真正需要思考的东西。

因此，整个自动化质量管理也是这样——如何让质量把控更恰当地卡住业务点，从而效率反馈，才是我们做自动化测试服务所要留意的地方。

通篇文章仅为个人见解。虽然现在自己的业务经验不够丰富，眼界也不一定够宽广，但希望多年之后，再次看到自己写过的文章，可以温故而知新。

总而言之，开了眼界，涨了见识，就是很爽！