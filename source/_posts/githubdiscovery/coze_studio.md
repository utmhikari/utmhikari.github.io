---
title: 【GitHub探索】Agent开发平台CozeStudio开源版本踩坑体验
date: 2025/08/03 14:09:12
categories:
- GitHub探索
tags:
- AI
- Agent
- Coze
- DDD
- LLM
---

近期Coze开源了自己的核心产品CozeStudio和CozeLoop，CozeStudio主要面向AI-Agent产品开发和周边生态，而CozeLoop主要面向Prompt Engineering以及效果评测。借这个机会，笔者也踩坑了下CozeStudio和CozeLoop的源码，在本地做了部署简单玩转了下，也顺带了解了下CozeStudio跟CozeLoop的一些产品原理。

本篇文章就先分享一下CozeStudio的踩坑体验，源码可以从[这个Repo](https://github.com/coze-dev/coze-studio)里面拉取。

<!-- more -->

CozeStudio采用DDD范式编码，整个后端框架分成api、app、domain、crossdomain以及infra等几层。要部署后端服务的话，由于CozeStudio采用DockerCompose，因此需要有Docker以及相关环境。这里笔者由于用的是Macbook，且用的公司电脑试水，因此采用Docker+Colima的选择，让CozeStudio能在Mac上面跑起来。如果需要调试代码的话，CozeStudio也提供了比较细致的文档指引，改了代码后make debug一下就能搞定。当然如果要直接套用开发的话，建议还是建大团队开发比较适合，因为纯DDD范式的编码层次结构边界太强，人少了迭代会很慢。

CozeStudio里面的内容主要是面向Agent开发业务的。要开发一个Agent的话，CozeStudio会为用户提供一个System Prompt，然后附带一些工具链，包括插件（不支持MCP，但类似，可以描述各个工具以及打标返回数据）、Eino Based Workflow、知识库（文本/表格等）以及记忆模块（变量）等内容。当然其中不论是Agent调试还是知识库持久化都是需要推理跟Embedding模型支持的，这里笔者就借助了公司便利，用了火山云的相关基建来满足需求。

如果把自然语言Prompt理解成Agent的字节码的话，那么整个Agent其实也可以看做成一个大Prompt，但如果你希望让Agent逻辑更加可控的话，也可以把主流程抽象成Workflow，然后在System Prompt里面要求大模型直接调用Workflow解决用户问题。从源码上来看，「SystemPrompt+各类工具能力」这个事情，本身也是通过一个硬编码的ComposeGraph来实现的。如果你发布了Agent，调用了Chat接口，其工作流程会是这样：

- 建立SSE连接
- OpenapiAgentRun：获取Agent信息，确认是否已有/新增用户会话，然后尝试执行Agent
- AgentRun：获取Agent历史，给SSE返回问答创建/进行中以及Ack等Message，然后开始推理消息
- StreamExecute：硬编码Compose一个Graph，把模型和Prompt、变量以及知识库/插件/Workflow的Retriever给绑定起来，构造一个ReAct+Suggestion的交互流程，然后执行整个Graph，不断给SSE返回Message数据。
