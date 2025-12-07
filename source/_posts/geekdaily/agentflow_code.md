---
title: 【极客日常】智能化工程AgentFlow代码实现分析
date: 2025/12/07 13:30:22
categories:
- 极客日常
tags:
- AgentFlow
- LLM
- AI
- 强化学习
- 源码分析
---

近期笔者因为参与LLM增强项目攻坚，对LLM工程相关的技术也希望有一定的了解，因此希望借这个机会，读一些文章充电，看看目前LLM智能化工程的一些研究趋势。在阅读了几篇文章之后，最终读者选定[AgentFlow](https://agentflow.stanford.edu/)这个项目做代码实现分析。由于笔者在算法方面的涉猎实在不深，所以本文只是抛砖引玉，阐述上有什么不专业不严谨的地方，也辛苦大家指正。

AgentFlow主要解决现有LLM在进行工具增强推理时有可扩展和泛化能力差的问题，简单来说就是在线LLM-Agent服务缺乏在生产环境中RL（强化学习）的手段。所以AgentFlow提出了以下的解决方案，一是一套动态训练Planner的编排，另外一个是一套奖励目标训练算法Flow-GRPO。源码可以通过[这个GitHub](https://github.com/lupantech/AgentFlow)来下载，跑了一番看Agent编排的实现比较完整，但在线服务跟训练的部署执行会比较难搞，所以本文更倾向于对Agent编排做详细阐述。

Agent编排包含Planner、Executor、Verifier跟Generator四个角色，Planner会不断Rollout判断下一步要做什么，Executor执行ToolCall，Verifier判断当前问题是否解决，Generator负责整合Output。整个核心代码集中在Solver.solve，长这个样子：

<!-- more -->

```python
class Solver:
    def solve(self, question: str, image_path: Optional[str] = None):
        # Update cache directory for the executor
        self.executor.set_query_cache_dir(self.root_cache_dir)

        # Initialize json_data with basic problem information
        json_data = {
            "query": question,
            "image": image_path
        }

        # Generate base response if requested
        if 'base' in self.output_types:
            base_response = self.planner.generate_base_response(question, image_path, self.max_tokens)
            json_data["base_response"] = base_response

        # If only base response is needed, save and return
        if set(self.output_types) == {'base'}:
            return json_data
    
        # Continue with query analysis and tool execution if final or direct responses are needed
        if {'final', 'direct'} & set(self.output_types):
            # [1] Analyze query
            query_start_time = time.time()
            query_analysis = self.planner.analyze_query(question, image_path)
            json_data["query_analysis"] = query_analysis

            # Main execution loop
            step_count = 0
            action_times = []
            while step_count < self.max_steps and (time.time() - query_start_time) < self.max_time:
                step_count += 1
                step_start_time = time.time()

                # [2] Generate next step
                local_start_time = time.time()
                next_step = self.planner.generate_next_step(
                    question, 
                    image_path, 
                    query_analysis, 
                    self.memory, 
                    step_count, 
                    self.max_steps,
                    json_data
                )
                context, sub_goal, tool_name = self.planner.extract_context_subgoal_and_tool(next_step)

                if tool_name is None or tool_name not in self.planner.available_tools:
                    print(f"\n==> 🚫 Error: Tool '{tool_name}' is not available or not found.")
                    command = "No command was generated because the tool was not found."
                    result = "No result was generated because the tool was not found."

                else:
                    # [3] Generate the tool command
                    local_start_time = time.time()
                    tool_command = self.executor.generate_tool_command(
                        question, 
                        image_path, 
                        context, 
                        sub_goal, 
                        tool_name, 
                        self.planner.toolbox_metadata[tool_name],
                        step_count,
                        json_data
                    )
                    analysis, explanation, command = self.executor.extract_explanation_and_command(tool_command)
                    
                    # [4] Execute the tool command
                    local_start_time = time.time()
                    result = self.executor.execute_tool_command(tool_name, command)
                    result = make_json_serializable_truncated(result) # Convert to JSON serializable format
                    json_data[f"tool_result_{step_count}"] = result
                
                # Track execution time for the current step
                execution_time_step = round(time.time() - step_start_time, 2)
                action_times.append(execution_time_step)

                # Update memory
                self.memory.add_action(step_count, tool_name, sub_goal, command, result)
                memory_actions = self.memory.get_actions()

                # [5] Verify memory (context verification)
                local_start_time = time.time()
                stop_verification = self.planner.verificate_context(
                    question, 
                    image_path, 
                    query_analysis, 
                    self.memory,
                    step_count,
                    json_data
                )
                context_verification, conclusion = self.planner.extract_conclusion(stop_verification)
                
                # Break the loop if the context is verified
                if conclusion == 'STOP':
                    break

            # Add memory and statistics to json_data
            json_data.update({
                "memory": memory_actions,
                "step_count": step_count,
                "execution_time": round(time.time() - query_start_time, 2),
            })

            # Generate final output if requested
            if 'final' in self.output_types:
                final_output = self.planner.generate_final_output(question, image_path, self.memory)
                json_data["final_output"] = final_output
                print(f"\n==> 🐙 Detailed Solution:\n\n{final_output}")

            # Generate direct output if requested
            if 'direct' in self.output_types:
                direct_output = self.planner.generate_direct_output(question, image_path, self.memory)
                json_data["direct_output"] = direct_output
                print(f"\n==> 🐙 Final Answer:\n\n{direct_output}")

            print(f"\n[Total Time]: {round(time.time() - query_start_time, 2)}s")
            print(f"\n==> ✅ Query Solved!")

        return json_data
```

详细来讲是这样一个流程：


- Analyze Query
    - Inputs：Question & Tools -> Inject Into Prompts
    - Outputs: Query Analysis -> Brief & Concise
- Main Execution Loop
    - Planner.generate_next_step
        - Inputs: Question, Query Analysis, Memory & StepCount -> Inject Into Prompts
        - Outputs: NextStep -> Justification, Context, SubGoal & ToolName
    - Planner.extract_subgoal_and_tool -> JSON or REGEX
        - Inputs: NextStep
        - Outputs: Context, SubGoal & ToolName
    - CallTool if tool is active
        - Executor.generate_tool_command
            - Inputs: Question, Context, SubGoal & ToolMeta -> Inject Into Prompts
            - Outputs: ToolCommand
        - Executor.extract_explanation_and_command
            - Inputs: ToolCommand
            - Outputs: analysis, explanation & command
        - Executor.execute_tool_command
            - Inputs: ToolName & Command
            - Outputs: Result
    - Memory.add_action
        - Inputs：StepCount, ToolName, SubGoal, Command, Result
    - Planner.verificate_context -> verify memory
        - Inputs: Question, Query Analysis, Memory, StepCount -> Inject Into Prompts
        - Outputs: Stop Verification -> Explanation + STOP/CONTINUE
    - Planner.extract_conclusion -> JSON or REGEX
        - Inputs: Stop Verification
        - Outputs: Context Verification (Explanation), Conclusion (STOP/CONTINUE)
    - Planner.generate_final_output/generate_direct_output
        - Inputs: Question, Memory -> Inject Into Prompts
        - Outputs: Chat Response

本质上这套流程是一个多回合的MDP（马尔可夫决策过程），通过上面4个模块的协作，不断逼近最合理的答案。但仅仅有这个框架还是不够的，纯Rollout逼近的效果理论上肯定没有经过训练之后的好。所以paper里采用Flow-GRPO这套体系提供生产环境训练能力，有两个关键点：

- QA奖励：单次QA奖励会广播到每个step，最终结果影响每个step的决策奖励；
- Group-Normalized-Advantages（组归一化优势）：在每个训练批次中，算法对同一批次（并行rollouts）所有轨迹的优势函数做归一化，确保优化梯度合理，本质也符合[GRPO](https://zhuanlan.zhihu.com/p/21046265072)的思路。

要详细了解AgentFlow这套GRPO实现的话，可以看[这个](https://zhuanlan.zhihu.com/p/1968984541726245379)以及[另一个](https://zhuanlan.zhihu.com/p/1960844370321347350)知乎文章，此处不再赘述。代码方面的话，目前笔者没有跑通，也有可能需要借助verl、cuda之类环境才可以把整个训练验证跑起来。从已有信息来看，也许训练逻辑走到了下面的代码，通过training_rollout_async和_solve_and_evaluate保证训练集的Rollout和评测可并发进行，然后产出一批rollout_data，但rollout_data的消费逻辑目前还不明确。具体的话，可以参考目前rollout的逻辑：

```python
class Rollout(LitAgent):
    async def _solve_and_evaluate(self, rollout: AgentFlowRollout, task: Any, step_n: int, val: bool = False):
        """A helper function to run the agent, parse the result, and evaluate it."""
        result = {}
        try:
            output_format = "When ready, output the final answer enclosed in <answer> and </answer> tags. Do not generate any content after the </answer> tag."
            prompt = task["question"] + " " + output_format
            # prompt = task["question"]
            result = rollout.solve(question=prompt)
            
            # Safely check for and extract the final answer
            if "direct_output" in result and result["direct_output"]:
                final_output = result["direct_output"]
                all_matches = re.findall(r"<answer>(.*?)</answer>", final_output, re.DOTALL)
                if all_matches:
                    answer = all_matches[-1].strip()
                else:
                    answer = final_output
            else:
                print("Warning: Result has no direct_output or direct_output is empty.")
                answer = "None"
        except Exception as e:
            print(f"Failure during agent execution: {str(e)}. Defaulting to 'None'.")
            answer = "None"

        # Evaluate the answer against the ground truth
        reward_value = await eval(task["question"], str(task["result"]), answer, val)  # reward is tracked with the decorator
        print("answer: {} ground_truth: {} reward: {}".format(answer, task["result"], reward_value))

        idx = task.get("extra_info", {}).get("idx", "unknown_idx")

        rollout_data = {
            "step": task.get("step", ""), # TODO: check whether it can be solved
            "idx": idx,
            "id": task.get("id", ""),
            "prompt": task["question"],
            "model":rollout.llm_engine,
            "tools":self.tools,
            "groundtruth": task.get("extra_info", {}).get("groundtruth", task["result"]),
            "answer_extracted": answer,
            "reward": reward_value,
            "total_result":result,
            "timestamp": datetime.now().isoformat(),
        }

        data_id = str(uuid.uuid4())
        filename = f"rollout_{data_id}.json"

        save_dir = self.val_rollout_dir if val else self.train_rollout_dir

        # This function now uses the `step_n` passed as an argument.
        step_dir = os.path.join(save_dir, f"step_{step_n}")
        
        idx_dir = os.path.join(step_dir, f"idx_{idx}")
        os.makedirs(idx_dir, exist_ok=True)

        json_count = sum(
            len([f for f in files if f.endswith(".json")])
            for root, dirs, files in os.walk(idx_dir)
        )
        assert json_count < self.rollout_num, \
            f"Too many rollouts for idx {idx}: already {json_count} >= {self.rollout_num}"

        save_path = os.path.join(idx_dir, filename)

        with open(save_path, "w") as f:
            json.dump(rollout_data, f, indent=2)

        print(f"Rollout data saved to: {save_path}")

    async def training_rollout_async(self, task: Any, rollout_id: str, resources: NamedResources, val: bool = False) -> Any:
        await self._initialize_run_once(resources)

        if self.training_agent is None:
            print("Initializing training agent...")
            llm: LLM = resources.get("main_llm")
            self.training_agent = get_agent(
                llm.model,
                llm.endpoint,
                temperature=self.train_temperature,
                tools = self.tools,
                max_steps = self.max_steps,
                tool_engine = self.tool_engine,
                resources = resources,
                max_tokens = self.max_tokens,
                output_type= self.output_type,
                timeout= self.timeout,
            )
        
        # filelock to determine step_n ---
        lock = FileLock(self.train_lock_file, timeout=30)
        with lock:
            step_dirs = [d for d in os.listdir(self.train_rollout_dir) if d.startswith("step_")]
            step_nums = [int(d.replace("step_", "")) for d in step_dirs if d.replace("step_", "").isdigit()]
            
            current_step_n = 1
            if step_nums:
                current_step_n = max(step_nums)

            current_step_dir = os.path.join(self.train_rollout_dir, f"step_{current_step_n}")
            if os.path.exists(current_step_dir):
                num_items_in_step = len(os.listdir(current_step_dir))
                if num_items_in_step >= self.train_batch_size:
                    current_step_n += 1
            
            step_n = current_step_n

        await self._solve_and_evaluate(self.training_agent, task, step_n, val)
```
