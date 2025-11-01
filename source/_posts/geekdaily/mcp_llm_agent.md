---
title: 【极客日常】浅聊基于MCP生态的LLM-Agent开发
date: 2025/04/12 22:58:30
categories:
- 极客日常
tags:
- MCP
- LLM
- 协议
- Agent
- AI
---

最近在AI大模型领域，MCP这个概念非常火，大大小小的公众号都开始对外炒作这个概念，宣教一种新的大模型Agent开发生态。因为工作原因，近期笔者也对MCP和LLM-Agent开发做了一些接触。因此今天这篇文章就浅聊下笔者对基于MCP的LLM-Agent开发方面，自己粗浅的一些理解。

首先还是聊一下什么是MCP，以及MCP在LLM-Agent开发方面，解决了什么问题。

<!-- more -->

MCP（Model Context Protocol，模型上下文协议）是由[做Claude的公司](https://modelcontextprotocol.io/introduction)制定的，其主要的作用是对大模型访问三方能力（OpenAPI、多模态数据源）定下规范。想象下，不管是本地部署的大模型还是remote的agent，或多或少都有访问本地DB、调用外部OpenAPI，或者获取外部的Prompt文本、图片等多模态资源的需求，而对于模型本身来讲，模型自己只能理解自然语言，反倒结构化的数据不好去理解，所以对于Agent开发者，还需要花很多精力去封装这些三方能力，才能够让模型做比较精确的意图识别。而MCP就通过一套协议约定，去解决这个问题，不同的三方能力用同一套描述方式做打标，并且在数据传输层也封装了stdio和sse两套方案，从而分别满足访问本地资源和访问外部资源的需求。

结合[Tool use with Claude](https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview)这篇文章，可以更好理解MCP要解决的问题。比如对于Claude大模型客户端，CallTool的过程，先是根据UserPrompt去识别决定要用哪个Tool，然后才是调用，拿到结果后处理成文本再返回。在[这篇文档](https://glama.ai/blog/2024-11-25-model-context-protocol-quickstart)里面也可以看到每个Tool定义的样子，一般用name、description（用途）和inputSchema（入参标注），就可以满足模型做用途识别和参数识别的需要。

MCP协议相当于对大模型的前端（Agent应用）和后端（三方工具）做了分离，提供了标准化且具备安全性的协议，所以在这个基础上，MCP-Server的市场生态也衍生了出来。比如[mcp.so](https://mcp.so/)，作为一个类似“网关”的角色，实现了大规模MCP-Server的在线托管，同样近期阿里云也提供了[MCP广场](https://bailian.console.aliyun.com/&tab=mcp#/mcp-market)的服务。看起来这种模式和传统的Web-OpenAPI市场比较类似，但不同点在于MCP主要面向大模型服务，能够提供多模态的数据，Web-OpenAPI并不重视这个，所以这个概念也不算非常重复。

对于Agent开发者而言，要封装三方工具，除了以往自主封装或者依靠框架约定做封装之外，现在也可以直接利用[mcp-go](https://github.com/mark3labs/mcp-go)之类的SDK，直接通过ListTools、CallTool等操作实现工具调用，并且各类框架现在也在逐渐跟进基于MCP协议的三方调用模式。从长远上来看，这种模式由很大的发展空间，但短期来看，这套连接的稳定可用性SLA保障基建其实还比较欠缺。所以个人建议对于Agent开发者来说，重点还是去打磨自己的Tool能力或Agent效果，但也要为长期把Tool迁移到MCP生态做准备。
