---
title: 【Game Of AutoTest】4、游戏自动化测试的稳定性保障
date: 2022/10/03 17:43:40
categories:
- Game Of AutoTest
tags:
- 自动化测试
- 稳定性
- 系统设计
- 游戏自动化
- 测试开发
---

在游戏自动化测试技术落地过程当中，如何保证自动化测试的稳定性，是一个需要重点优先解决的困难问题。

以手机游戏客户端自动化测试为例，和一般服务架构的自动化单元测试或集成测试不同，自动化驱动的过程，其本质更加类似于网络爬虫，每次测试执行都是一个时间较长的过程，而流程一长，不稳定因素则随之而来。游戏自动化的整个过程，大致是这样的：

- 前置环境准备（setup）：设置用例运行环境、设备状态与玩家状态，保证用例运行的条件
- 用例脚本执行（run）：执行自动化用例脚本
- 后置恢复操作（teardown）：恢复测试环境、设备状态与玩家状态
- 测试报告输出（report）：整合跑测期间游戏的运行数据与用例脚本收集/导出的数据，生成测试报告

要分析如何保障整个自动化过程的稳定性，我们可以根据这几个步骤进行细节切分，对每一个环节影响稳定性的因素逐个理顺，从而最终，我们就可以得到一整套自动化稳定性保障的解决方案。在这四个步骤当中，前置环境准备和用例脚本执行这两步，对自动化流程稳定性的影响面最大，而最后面两步的影响程度，则相对较低。

<!-- more -->

## 前置环境准备

前置环境准备步骤，在本地环境执行较为方便，人工手动去设置设备环境跟玩家状态就可以。但是在平台化运行场景下，需要考虑全自动的任务调度、自动装包、账号环境准备等流程。其中每一个因素，都会影响整个自动化流程的稳定性。

从手机自动化测试平台的设计来看，除了一个云真机平台所必需的设备管理、项目管理、用例管理等必须的功能之外，最需要推敲的还是任务调度这一部分。任务调度模块需要管理并实时监控所有运行中的自动化任务，单个自动化任务的运行以及对应的系统设计，大概是这样：

- 任务创建：指定自动化用例集、测试设备，创建一个自动化任务
  - 任务管理模块存储自动化任务定义到数据库
- 运行任务实例：用户为任务指定选择客户端版本，触发单个任务实例的执行
  - 任务调度模块根据任务里测试设备的声明，确定合适的测试设备执行自动化任务
  - 任务调度模块创建一个任务实例记录以及多个关联的用例执行实例记录，存储到数据库
  - 任务调度模块将任务下发给测试设备对应的`PC-Agent`
  - 在缓存中备份一份任务和用例运行的状态信息，用于在新的状态上报时，快速获取并对比状态信息，确认任务和用例执行记录是否更新
- 用例执行：`Agent`接收任务后，创建自动化测试用例所必需的运行环境，并按照用例集定义执行用例
  - 指定的设备执行用例有排队机制，只有前面的用例执行完，才能执行新的用例
  - 执行用例前，`Agent`需要和`CI`平台打通，实现自动下包、装包的流程
  - 实际测试用例执行前，需要实现游戏的账号登录和进游过程，这一过程也需要抽象成一个前置用例
  - 准备好一切后，才执行实际的测试用例
- 设备执行状态更新
  - `PC-Agent`在下包装包、前置用例、实际测试用例执行期间，以固定频率上报当前用例（包含对应任务实例ID）的执行状态。任务调度模块在用例/任务状态变化情况下，更新数据库信息
  - 当一个用例执行完毕，任务调度模块标记该用例执行实例已完成，并更新对应任务实例的统计信息
  - 当所有机器所有用例执行完毕（或者异常中断），整个自动化任务实例结束，任务管理模块标记对应任务实例已完成

因此，我们需要从自动化平台`infra`方以及自动化用例开发方两个角度，去分析保障自动化稳定性需要考量的一些点。
从平台`infra`方的角度考虑，要维持自动化流程的稳定性，除去技术设施本身程序稳定性外，在系统设计上，需要重点关注：

- 任务调度模块对于任一用例的所有执行步骤，需要建立超时失败机制，防止状态阻塞
  - `CI`下包接口失效、用例执行时间过长、`Agent`宕机、执行机器无故迁移，都会引起用例卡状态
  - 任务调度模块需要在特定状态持续时间过长，或是与`Agent`断连的情况下，主动标识用例运行异常
- 对于长时间排队无法执行的用例，任务调度模块可考虑增加重调度机制，把用例重新安排到其他空闲的机器运行
  - 从业务角度来讲，长时间排队也是自动化不稳定的一种情况，因为会导致用例无法在期望的时间期限中完成执行，从而达不到自动化测试的效果

从业务自动化开发的角度考虑，在用例执行环境构造方面，需要重点关注：

- 单独维护一个游戏的更新、登录用例，保证这个用例的稳定性
  - 登录进游用例是实际测试用例的基础，如果登陆进游失败会直接导致测试用例无法执行
  - 用尽可能保守的逻辑触达每个分支，比如对于拉起第三方`app`登录的过程，每一步都考虑建立多次重试的机制。时间不是问题，成功率才是问题。
- 测试账号需要实时维护，同时也需要考量维护的成本
  - 如果测试账号量大，但因为游戏新特性发布导致各种弹窗的出现，可以统一在测试用例的`setup`步骤中抽象出来，从而解决同类问题
  - 如果游戏有账号数据复制这一机制的支持，可以优先用来保证玩家能够快速达到用例执行的前置状态

## 用例脚本执行

用例脚本执行期间的稳定性，是自动化业务逻辑保证的。除去代码质量外，合适的自动化流程和代码设计，是保证自动化稳定性的根本。
在[框架设计](https://utmhikari.top/2022/09/04/gameofautotest/iii/)一文当中，笔者强调了行为驱动对于自动化开发的重要性，通过对行为层面的抽象，用例开发者不必关心行为的具体实现，只需组装玩家行为，即可实现自动化流程。因此，行为库，作为自动化逻辑的基础，是影响自动化稳定性的关键。

自动化行为可以通过脚本驱动和UI驱动实现。至于如何提升行为实现的稳定性，这里就给出几个tips可以参考：

- 脚本自动化
  - 在客户端游戏代码中抽象一层自动化专属模块，用于整合基础常用的游戏接口
    - 客户端开发的目标是仿真，而非原子串行地执行玩家行为，因此客户端许多原生接口的实现是被动响应式的，不一定直接满足自动化主动执行的需求
    - 游戏接口调用尽量挑业务底层模块的，一般接口名不会有太多变化，减少自动化专属模块的维护量
    - 抽象自动化专属模块，同时可以让自动化逻辑更加可控，防止开发频繁修改游戏接口实现导致的不稳定性
  - 在框架代码中，基于游戏自动化模块再抽象一个接口层，在接口实现里组装代码和参数
    - 需要实现一个通用方法，将框架运行时的数据对象转化成游戏脚本代码的表达形式
    - 效果上，用例开发者无需关心代码组装逻辑，进一步减少脚本驱动逻辑开发难度，提升代码易读性
- UI自动化
  - 如果控件名称或者控件文本较为独特唯一，优先用控件名称或文本作为UI的筛选条件
    - 如果是动态生成的控件，以`UE4`为例，控件名会有ID后缀，因此不能采取全文匹配，可以用关键字匹配
  - 如果是容器内（如列表）的一批控件，控件名/文本都相同，需要筛选其中一个的话，可以通过子控件的独特性来筛选
    - 游戏迭代过程中，控件之间的层级关系一般不会有太大的变化，因此可以通过子控件筛选来反推父控件，并且这种逻辑维护起来也比较方便
  - 对于包含图像的控件，优先用图像资源路径的关键字进行匹配，再次之用图像识别
    - 资源路径的关键字特征通常较明显，实际使用时也通常能筛选出屏幕中唯一的那一个
    - 图像识别方案，一来会被图像识别技术本身的不稳定性影响；二来游戏迭代过程中，相对于控件/资源名的关键字变化，UI样式变化会来的多，但图像识别方案是不能接受UI样式变化的。因此，如果需要大规模使用UI自动化情况下，图像识别方案需要谨慎选择。
  - 通过控件树前后是否变化，判断UI操作是否生效，并抽象重试机制，提升UI自动化的容错性
  - 不直接用控件ID、控件坐标筛选控件，因为无法直接兼容到其他机器

这些tips，即便是在自动化业务逻辑里，需要实现一些游戏行为的场景下，也都是通用的。

在行为库一层之上，自动化业务逻辑的稳定性，其实多取决于测试业务本身的复杂度，以及用例开发者的业务理解跟编码水平。在这里，就需要考虑自动化业务选型和流程设计了。为了规避可能的不稳定性，发挥自动化技术的价值，这里也有几个tips可以参考：

- 选择操作不复杂，但遍历量大的场景，实现自动化遍历
- 选择人工测试操作复杂，但可以通过直接和游戏程序运行时交互去收集数据/执行测试的场景，实现自动化遍历
- 在同时有多个测试点的情况下，每个测试点执行过后，需要有执行失败的兜底逻辑，恢复玩家状态，从而能继续测试
  - 如果兜底方式不明确，可考虑设计成能够串行执行+`fast-fail`立即终止的形式
  - 通过配置驱动来动态决定哪些测试点需要执行
- 业务功能自动化测试场景下，一个用例尽量只专注于一类测试点，不要在自动化流程期间验证很多分支测试点
  - 会引起用例代码量过大，逻辑复杂，难以维护
  - 自动化测试无法代替功能测试全部内容，真正代替的是测试人力，需要强调下这个思路
  
## 后置恢复操作

自动化用例的后置恢复操作，对自动化整个流程的稳定性影响不是特别大。这部分，只有几点需要注意：

- 对于有前后继关系的测试用例，每个用例的后置恢复操作，需要和先前所述一样，实质是一个失败兜底逻辑，保证玩家状态恢复正常，或者达到能直接检测到`fast-fail`的形式
- 对于单个机器运行多个用例的情况，保证机器能够稳定恢复到未装游戏之前的状态即可

## 测试报告输出

测试报告是自动化测试的重要部分，只有测试报告才能够证明自动化测试是有效的。因此，能保障测试报告的有效性，也就可以保障自动化测试报告环节的执行稳定性。

对于测试报告的整合输出过程，有几点需要注意：

- 一份有效的自动化报告，应当聚焦于自动化的测试目标，最优先是用程序分析的方式直接给出结论，再次则给出一系列有用的数据/截图/录屏到人工二次排查
  - 针对业务功能的自动化测试，测试的对象不是程序本身，而是基于人类的业务设计和测试经验。这种情况下强求用程序分析错误根因不现实，从实用角度来讲，应该要统一做成数据呈现+人工排查的`半自动化`形式。
  - 需要做到的效果是，如果自动化报告会被标注为成功，那么整个过程是一定被信任的，默认是没有发现问题。只有标注失败的用例，才需要做人工介入。
- 自动化过程耗时较长，不可避免会因为崩溃、设备断线等原因，出现用例执行中途断掉的情况。因此自动化业务逻辑需要有根据已有报告存档，在测试过程中忽略已测试内容的机制，从而避免冗余测试的情况。
  - 这种机制下，可以满足测试用例随时停止重启的需求，不同测试用例的报告可以随时合并，成为汇总的报告内容。

自动化测试报告一般需要持久化保存，对于一些耗时较长、输出截图/录屏量较大的用例，用**对象存储**是最适合做报告持久化的。

在业务功能自动化测试领域，对于大规模冒烟监控的场景，需要考虑到测试报告分析的人力成本。这种情况下，报告分析成本和自动化执行的时间是成正比的，因此，如果自动化测试通入的人力不多，需要酌情控制自动化测试的规模，防止无意义的人力成本消耗，导致没有更多的时间去维护已有用例的稳定性，或者开发新场景的用例。

## 总结

自动化测试的稳定性，作为一个重点问题，其解决方案，并非一言以蔽之的固定套路，而更多是技术细节的累积，以及测试工作者实事求是的分析。本文主要从笔者工作经验出发，讲述一种保障游戏自动化测试稳定性的方法，希望各位读者/同行能够通过这篇文章，对于`自动化测试稳定性`这一命题，拥有更新的理解。
