---
title: 【Game Of AutoTest】3、游戏自动化测试的框架设计
date: 2022/09/04 15:52:17
categories:
- Game Of AutoTest
tags:
- 自动化测试
- 自动化框架
- python
- BDD
- 依赖注入
---

自动化在技术层面上，除了基础的技术选型之外，最终还是需要落实到具体的工具框架，才能够助力我们自动化脚本开发的过程。因此，本文将讲述一下如何对游戏自动化测试框架进行设计。

在[上一篇文章](https://utmhikari.top/2022/08/13/gameofautotest/ii/)讲到，自动化测试的方式可以有客户端、服务器、编辑器三种方式，除了编辑器需要强依赖引擎层面的特性之外，其他两种自动化方式在工具或者框架的技术实现上有这么几个特点：

- 框架模块设计具有共通性，只是最终执行自动化用例/脚本的方式不同
- 许多框架模块可以不依赖游戏本身的特性去实现，可以实现很多企业业务功能的集成
- 由于和产品没有太多的耦合，可以做成易于在不同项目测试之间迁移通用的形式

考虑到当前我国有许多游戏企业的工作习惯是，测试由中台dispatch到各个项目，不直接参与研发过程（Code Review？不存在的），项目产品以提测的方式交付测试，测试侧可以运用自己的测试手法和工具去完成任务。从这样的角度看，拥有一个功能性强且通用的自动化测试工具，不仅是对于项目所需要自动化测试的场景，更是对于测试组整体的技术基建提升而言，都显得非常重要。

以笔者工作经验为参考，要做到游戏自动化框架得以通用，设计上需要遵循如下准则：

<!-- more -->

- 技术集成
   - 在自动化逻辑实现方面，尽可能集成更多的自动化底层技术方案
   - 在自动化业务落地方面，尽可能集成更多报告工具以及通用业务SDK
      - 报告工具包括：录屏、截图、日志分析、通用报告输出、IM/邮件推送等
      - 通用业务SDK：这个比较灵活，根据各个企业内具体业务而定
- 用例隔离
   - 业务用例和框架底层相互隔离，通过接口约定或是依赖注入的方式衔接起来
   - 不同用例之间，在逻辑意义上，不应出现相互的模块引用，有共性的需求需要抽象到框架当中
   - 不同用例之间，在物理意义上，由框架统一管理各个用例的内容（脚本、配置）和运行时状态，测试人员通过启动框架去间接驱动用例的运行
- 行为驱动
   - 在玩家行为层面上，对于每类玩法以及系统功能，抽象出基础接口集
   - 在自动化测试层面上，对于每类固化的自动测试流程，抽象出固化的行为策略
  
## 技术集成

技术集成，从一个框架的角度而言，能集成更多的功能肯定是更好的。在技术集成方面需要分成两块考虑，一块是自动化的实现，我们需要把先前提到的各种自动化技术方案都整合进来，大多数业界开源的框架也都是这样做的。

另一块是具体到业务方面，就是在技术实现的基础上，怎样提升自动化的开发效率，怎样让自动化跟实际测试业务衔接的更好。这一part相比于自动化底层技术实现是更加重要的，因为会影响到自动化框架落地到业务的效果。

针对后者，开源框架和工具很难你这些，而就算企业内部做的许多技术方案，以笔者的经历来看，基本都缺乏这方面的思考沉淀。因此，如果是从0到1实现自动化测试的情况，建议是从具体业务出发，找一个适用于应用自动化技术的玩法测试场景，实事求是去琢磨一下。

## 用例隔离

用例隔离，包含两个方面，一块是用例逻辑和框架逻辑的隔离，一块是不同用例之间的隔离。

针对前者，用例和框架的隔离，需要强调框架本身存在的意义是为用例提供运行环境还有便捷的功能接口，不应当依赖于用例本身，或者说，就算是非游戏领域的自动化测试甚至其他需求，用这个框架稍微改装一下就可以完成，这是框架作为底层基础需要达到的效果。

针对不同用例之间的隔离，严格意义上需要达到的效果是，用例本身的版本迭代是独立的，不同的用例开发者可以在相同版本框架的基础上开发不同的内容，最终这些内容都无冲突地合入到同一个开发分支。如果有可以抽象出来的内容，可以由框架开发者统一整理并入，也可以由用例开发者请求合入（这种情况有冲突的可能性），总之都是为了让框架集成的功能更加丰富。

在这样的设计基础上，用例的执行是需要框架机制驱动的，以笔者的经验为例，在`python`框架的场景下，可以参考下述方式实现。首先，框架可以呈现这样的目录结构：

- `cfg`：框架配置
- `engine`：框架核心逻辑
- `testcases`：用例集根目录
   - `testcase_1`：用例1的工作目录
      - `main.py`：用例1的入口
- `main.py`：框架入口

之后，在`main.py`中，用例开发者需要实现一个`run`函数，作为真实的用例跑测逻辑。`run`函数的入参可以是框架的一些特性实例，比如脚本/UI自动化的`Handle`。从用例开发者角度而言，不需要关心这些`Handle`的来源，可以直接拿来用；从框架开发者角度而言，框架需要根据用例的运行配置创建这些特性实例，然后`inject`给用例的`run`接口。

```python
# testcases/testcase_1/main.py
def run(r: RunnerHandle, d: DeviceHandle, s: ScriptHandle, u: UIHandle) -> Result:
	"""
    main entry of testcase logic
    handles will be automatically injected by the autotest framework
    :param r: handle of current runner, use this instance to log or get env-vars of testcase runtime
 	:param d: handle of device
    :param s: handle of script-based autotest
    :param u: handle of ui-based autotest
    :return: testcase result
    """
    # 用例：关闭商城界面
    r.logger.info('start testcase_1!')
	s.send('print("helloworld")')
    d.screenshot('before_close')
	if u.find_and_click(name='BtnClose_Mall'):
        r.logger.info('found and clicked close-btn of mall panel')
        time.sleep(3)
        d.screenshot('after_close')
    else:
        r.logger.error('failed to find close-btn of mall panel')
    if s.call('UIModule.IsInMainPanel()').boolval():
	    return Result.ok(message='successfully closed mall panel')
    else:
        return Result.err(message='failed to close mall panel')

```

最后，框架内部需要有一个通过`用例名`配置，从而动态`import`到`testcases/用例名`下的`main`模块，并调用`run`接口的运行机制。从用例开发者的角度，框架配置在`cfg`目录下指定（命令行也可以），之后运行框架入口脚本`main.py`，达到运行用例逻辑的效果。

## 行为驱动

（游戏）自动化用例本质是一系列用户（玩家）行为的组装，因此在面向游戏自动化测试的框架设计上，需要充分对游戏行为进行抽象，使得不同的游戏行为能够复用到各个用例当中，减少用例代码量以及编写难度。

自动化的行为分为两种粒度，一种是测试玩家单个操作的粒度，好比说，打开某个玩法的界面、进入某玩法位面、设置某种画质，甚至是说查询任务进度数据、执行恢复状态GM命令这种，都属于测试玩家的单个操作。这些行为可以随时随地被不同的用例复用，拼装成整个自动化流程

举个例子，我们有`登录游戏`以及`玩PVP`的测试场景，这两个场景会遇到`等待加载`的过程，因此在自动化逻辑实现上，就可以抽象出`等待加载`的操作，放到单独的地方。代码实现如下：

```python
# scene.py，场景模块（公共）
def is_loading() -> bool:
    script_handle = ScriptHandle.current()
    resp = script_handle.call('SceneModule.IsLoading()')
    return resp.boolval()


def wait_for_loading(timeout=20, interval=3) -> bool:
	if not is_loading():
        return True
	for _ in range(timeout):
        time.sleep(interval)
        if not is_loading():
            return True
    return False


# 登录游戏
def login_game() -> bool:
    login_server(player_id=123, server_id=456)
    time.sleep(3)
    if not scene.wait_for_loading():
        return False
    if not is_in_game():
        return False
    return True


# 玩PVP
def play_pvp() -> bool:
    start_pvp_match(scene_id=999)
    time.sleep(3)
    if not scene.wait_for_loading():
        return False
    if not is_in_pvp():
        return False
    return True

```

第二种粒度的行为是固化的自动化流程，这个流程可以指玩法流程，比如某个副本的行为树逻辑，也可以指测试流程，比如`buff`效果测试，只要给这个流程指定一些`buffID`，就可以自动执行`addBuff`、`checkPlayerState`之类的测试逻辑。这一类的行为是以第一类的行为为基础搭建而成的，从用例开发者角度来看，只需要自定义流程属性（类似行为树的黑板）以及重载一些流程中钩子函数的实现，就可以把自己需要的自动化逻辑搭建起来。

比如我们需要实现`跑副本`的操作，那么我们就可以抽象单独的副本流程出来，尽可能复用到游戏里所有独立的副本当中。我们可以根据[副本自动化测试](https://utmhikari.top/2021/05/20/testlife/dungeon_autotest/)一文所示的方式去构建一个基础的副本流程类，然后再根据我们游戏的具体情况去实现一版副本跑测类，最后就可以通过这个跑测类来适配所有独立的副本。代码示例如下：

```python
class DungeonBehavior:
    """基础副本流程，参考【副本自动化测试】文章的实现"""
    pass


class MyGameDungeonBehavior(DungeonBehavior):
    """当前游戏的副本流程实现"""
    def __init__(self, dungeon_id: int, **kwargs):
        DungeonBehavior.__init__(self, **kwargs)
        self._dungeon_id = dungeon_id

	def update_state(self):
        """implement update_state step upon MyGame here"""
        pass

	def on_state_changed(self):
        """implement on_state_changed step upon here"""
        pass


class ChaosSanctuaryDungeonBehavior(MyGameDungeonBehavior):
    """假设有个叫做【混沌避难所】的副本"""
    def __init__(self, **kwargs):
        MyGameDungeonBehavior.__init__(self, 123, **kwargs)
        self.is_diablo_exist = False

	def update_state(self):
        MyGameDungeonBehavior.update_state(self)
        self.is_diablo_exist = entity.has_entity(entity_id=99999)

    def get_state(self):
        default_state = MyGameDungeonBehavior.get_state(self)
    	return f'{default_state}_{self.is_diablo_exist}'

```

如果有条件的话，可以编写行为树框架+可视化工具，甚至是能够实现BDD的原语支持，这样都能进一步提效自动化的开发。

通过对不同粒度的游戏行为进行抽象，不论是用例编写还是逻辑维护上，容易层度都可以上一个台阶。**这一part的组织，是自动化框架设计当中最为重要的一环。**

## 模块分层

基于上述的设计思路，自动化框架可以依据这样的模块分层进行设计：

- 框架底层
   - 基础逻辑：包括运行时配置管理、环境管理、依赖注入等机制
   - 技术方案组件/插件化：包括设备操作模块、自动化底层技术、报告工具以及业务SDK等内容
   - 用例运行：包括配置与脚本加载、用例运行监控、测试结果输出等内容
- 游戏业务层
   - 玩家行为、自动化测试行为的封装
   - 脚本/UI等自动化底层实现的封装
      - 根据每个游戏具体情况开发相关内容
      - 脚本自动化，建议在游戏代码基础上，编写一层单独的自动化模块，使得拼装游戏脚本代码更加方便
   - 仅适用于本游戏的工具/业务SDK内容
- 用例层
   - 用例运行配置
   - 准备数据：主要是游戏的配置数据，也可以考虑在脚本代码中动态获取的方式
   - 用例脚本代码
  
## 工具扩展

如果把自动化框架这个概念向外延伸的话，那么除了基础框架本身之外，还需要周边工具的支持，才能最大化提升自动化测试的体验。
这些工具不一定需要集成到框架里，可以包括：

- 调试工具：能够实现针对单个脚本/UI自动化逻辑给予即时结果反馈，用于日常开发调试用
- 代码生成工具：如行为树/脚本可视化编程、UI录制回放等，用于快速生成模板代码或是自动化逻辑
- 准备数据生成工具：用于快速生成某种玩法自动化测试所需的配置/用例数据
- 结果可视化工具：用于可视化展现自动化测试的结果
- IDE：简化研发过程

## 总结

作为游戏自动化测试框架来讲，既然是底层框架，那么打铁还需自身硬。除了上面说的一些设计理念跟工具选型，一些基础的方面，工程化、产品化的技术原则，比如保证稳定性、易扩展性、易上手性，高内聚低耦合，丰富的文档包装，SLA意识，这些都是通用框架设计落地必须具备的东西。自动化框架之于自动化用例，犹如游戏引擎之于游戏业务逻辑。如果框架开发者不去深入调研业务过程，而是纯粹堆砌自动化底层技术，那这类框架的结果，只能是炒作到大规模**试用**，而永远不可能在单个游戏项目内实现大规模**应用**。遗憾的是，在业界这种半成品依然大行其道。

最后还是得讲点东西，从游戏测试行业的角度来看，国内许多企业都执行中台测开+项目业务测试+中台/项目专项测试的模式，但由于项目测试通常有较高tick的工作模式，中台的工作模式通常又是服务多个项目组，就会造成对于许多技术测试需求，中台的支持效率就会显得很低，同时各项目测试因为不能及时得到支持，工作产出效能也会有所下降。以研发通用的自动化测试框架为例，建议采取的模式是，中台测试主控基础模块开发与业务特性合入，项目测试参与业务特性研发，并能随时申请合入一些自己项目遇到且可以通用给其他项目的内容。这样的开发模式下，不仅可以解决中台测试服务效率的问题，也能充分发挥项目测试的业务理解力和生产力，同时也能在不涉及保密问题的条件下最大限度集成各类技术模块。而更重要的，是可以加强不同测试团队之间的交流，减少信息的不对称性，这点从部门战斗力建设角度来讲，着实大有裨益。
