---
title: 【GitHub探索】代码开发AI辅助工具trae-agent
date: 2025/11/01 20:20:20
categories:
- GitHub探索
tags:
- trae-agent
- LLM
- AI
- 工具开发
- Agent
---

作为国内表现上比较agentic的开发工具之一，trae项目开源了自家trae-agent开发工具，整体也有一段时间了。借着日常闲暇的机会，笔者计划研究下trae-agent的代码实现，看下这个本地AI开发辅助工具是如何运作的。

从开源项目的角度，trae-agent给的文档信息是比较充足的，但代码实现上只能说是MVP版本，只有一些基础功能。当然这个也可以理解，相信实际生产用的trae-agent会远比这个实现更加复杂，以及不可能所有人力都投入到开源项目的建设中。所以今天就简单看看这个项目的主流程。

<!-- more -->

主流程的话在agent.py当中，可以参考最深处BaseAgent中execute_task和_run_llm_step的实现，此处展示下基础流程部分：

```python
class BaseAgent(ABC):
    async def execute_task(self) -> AgentExecution:
        try:
            messages = self._initial_messages
            step_number = 1
            execution.agent_state = AgentState.RUNNING

            while step_number <= self._max_steps:
                step = AgentStep(step_number=step_number, state=AgentStepState.THINKING)
                try: # 调用_run_llm_step和llm做chat
                    messages = await self._run_llm_step(step, messages, execution)
                    await self._finalize_step( # 记录trace
                        step, messages, execution
                    )  # record trajectory for this step and update the CLI console
                    if execution.agent_state == AgentState.COMPLETED:
                        break
                    step_number += 1
                except Exception as error:
                    execution.agent_state = AgentState.ERROR
                    step.state = AgentStepState.ERROR
                    step.error = str(error)
                    await self._finalize_step(step, messages, execution)
                    break
            if step_number > self._max_steps and not execution.success:
                execution.final_result = "Task execution exceeded maximum steps without completion."
                execution.agent_state = AgentState.ERROR
        return execution

    async def _run_llm_step(
        self, step: "AgentStep", messages: list["LLMMessage"], execution: "AgentExecution"
    ) -> list["LLMMessage"]:
        # Display thinking state
        step.state = AgentStepState.THINKING
        self._update_cli_console(step, execution)
        # Get LLM response
        llm_response = self._llm_client.chat(messages, self._model_config, self._tools)
        step.llm_response = llm_response

        # Display step with LLM response
        self._update_cli_console(step, execution)

        # Update token usage
        self._update_llm_usage(llm_response, execution)

        if self.llm_indicates_task_completed(llm_response):
            if self._is_task_completed(llm_response):
                execution.agent_state = AgentState.COMPLETED
                execution.final_result = llm_response.content
                execution.success = True
                return messages
            else:
                execution.agent_state = AgentState.RUNNING
                return [LLMMessage(role="user", content=self.task_incomplete_message())]
        else:
            tool_calls = llm_response.tool_calls
            return await self._tool_call_handler(tool_calls, step)

# 支默认持的tools
tools_registry: dict[str, type[Tool]] = {
    "bash": BashTool,
    "str_replace_based_edit_tool": TextEditorTool,
    "json_edit_tool": JSONEditTool,
    "sequentialthinking": SequentialThinkingTool,
    "task_done": TaskDoneTool,
    "ckg": CKGTool,
}
```

在设置里头我们可以设置每个问题的最大step次数，execute_task中就通过loop去要求LLM不断迭代问题解决方案。_run_llm_step中则传递历史消息和tools给到LLM，_llm_client支持了多个provider，给回结果后，通过匹配硬编码的关键字判断是否完成task，否则继续迭代，当然如果识别出需要tool-call的话，就由代码逻辑主动调用对应tool。

针对messages，在execute_task的caller的new_task过程中，已经注入了硬编码的system-prompt，以及带模板的user-prompt，可以在agent_prompt.py中看到。

```python
TRAE_AGENT_SYSTEM_PROMPT = """You are an expert AI software engineering agent.

File Path Rule: All tools that take a `file_path` as an argument require an **absolute path**. You MUST construct the full, absolute path by combining the `[Project root path]` provided in the user's message with the file's path inside the project.

For example, if the project root is `/home/user/my_project` and you need to edit `src/main.py`, the correct `file_path` argument is `/home/user/my_project/src/main.py`. Do NOT use relative paths like `src/main.py`.

Your primary goal is to resolve a given GitHub issue by navigating the provided codebase, identifying the root cause of the bug, implementing a robust fix, and ensuring your changes are safe and well-tested.

Follow these steps methodically:"""
# 下面忽略


class TraeAgent(BaseAgent):
    @override
    def new_task(
        self,
        task: str,
        extra_args: dict[str, str] | None = None,
        tool_names: list[str] | None = None,
    ):
        # fixed system prompt
        self._initial_messages: list[LLMMessage] = []
        self._initial_messages.append(LLMMessage(role="system", content=self.get_system_prompt()))

        # user message with issue to solve
        user_message = ""
        if not extra_args:
            raise AgentError("Project path and issue information are required.")
        if "project_path" not in extra_args:
            raise AgentError("Project path is required")

        self.project_path = extra_args.get("project_path", "")
        if self.docker_config:
            user_message += r"[Project root path]:\workspace\n\n"
        else:
            user_message += f"[Project root path]:\n{self.project_path}\n\n"

        if "issue" in extra_args:
            user_message += f"[Problem statement]: We're currently solving the following issue within our repository. Here's the issue text:\n{extra_args['issue']}\n"
        optional_attrs_to_set = ["base_commit", "must_patch", "patch_path"]
        for attr in optional_attrs_to_set:
            if attr in extra_args:
                setattr(self, attr, extra_args[attr])

        self._initial_messages.append(LLMMessage(role="user", content=user_message))
```

由于每次message只传递当次问答的message，所以针对单个问题，每个LLMClient需要实现对历史问答的记录。比如OllamaClient的实现：

```python
class OllamaClient(BaseLLMClient):
    @override
    def chat(
        self,
        messages: list[LLMMessage],
        model_config: ModelConfig,
        tools: list[Tool] | None = None,
        reuse_history: bool = True,
    ) -> LLMResponse:
        msgs: ResponseInputParam = self.parse_messages(messages)
        if reuse_history:
            self.message_history = self.message_history + msgs
        else:
            self.message_history = msgs
```

主流程大概是这些，代码架构上来看实现也不算太复杂，用专有Agent框架复刻也是可以的，然后硬编码注入的内容比较多，所以整体上来看trae-agent开源版离实际投产的标准还有一些距离。如果自己的项目要复用这套框架开发内容，最好保证以下事情，一是有一个足够可靠确定性高的模型，二是需要单独一套prompt管理模块把硬编码注入的prompt等文本做统一管理，三是有一套执行稳定性跟评测机制让整个agent过程能够针对自己项目的问题给出解决方案，至少得有面子上过得去的output才行。
