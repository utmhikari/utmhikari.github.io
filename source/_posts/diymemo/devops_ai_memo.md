---
title: 【DIY小记】用OCR和大模型GPT生成的《软件研发效能权威指南》读书笔记
date: 2024/04/21 16:44:33
categories:
- DIY小记
tags:
- OCR
- AI
- 大模型
- GPT
- DevOps
---

## 前言

[《软件研发效能权威指南》](https://book.douban.com/subject/36116375/)一书，对于软件研发效能DevOps领域做什么事情，解决什么问题，给出了非常全面详尽的说明。这本书的精华，基本全部都浓缩在一张附属的海报上，海报讲述了每个章节的精简摘要，可以说是现成的读书笔记。

2024年，相对于古早的纸质载体，用电子作为载体的文献在维护上成本更为低廉，并且也逐渐成为了最优的文献阅读方案。因此，顺带借着AI的东风，笔者决定用AI技术，将这份海报转化成一份电子版的读书笔记，通过OCR识别+GPT润色+人工校对，把这本书所有的精华给摘录下来。

以下，便是读书笔记的正文。

<!-- more -->

## 第1章 研发效能概述

### 1.1 研发效能的定义、目标及解决的问题

研发效能，指的是在研发过程中实现高效、高质量、可靠和可持续的业务价值交付的能力。这既涉及确保“做正确的事情”，也强调“正确地做事情并追求速度”。在组织层面，研发效能的核心在于通过优化流程和工具，提升团队的产出效率和质量。而在个人层面，它更注重个人的能力成长和聪明地工作，而非仅仅是投入的努力。随着软件规模和复杂性的提升，研发效能需要解决如何保持高效并减缓效能恶化的挑战。

### 1.2 研发效能的实践框架

构建研发效能的“黄金三角”，涵盖效能实践、效能平台和效能度量三个关键部分，三者相互促进，共同提升研发效能。坚持正确的价值主张，确保在做正确的事情的同时，也追求正确的工作方式。效能实践应因地制宜，以解决瓶颈为目标，持续改进。效能平台应满足研发场景需求，注重工具间的连通性。效能度量则应指导并驱动有效的效能提升，基于数据驱动和实验思维进行。

### 1.3 研发效能的实施策略

实施研发效能提升时，应注重解决实际的研发“痛点”和问题，避免形式主义或虚假繁荣。这需要业务研发团队、工具平台团队、效能专家或教练团队以及组织级研效管理团队共同协作。明确各自的角色和职责，确保策略在不同场景下的灵活性和实用性。同时，研发效能应服务于业务，而非让业务迁就效能。

### 1.4 研发效能的核心价值观和常见误区

研发效能的核心价值观包括以业务价值为导向、优化全局流动、追求工程卓越和善用数据思维。在实施过程中，应避免的常见误区包括缺乏系统化规划、盲目推行一致性、形式主义工程实践、忽视上下文差异照搬方案、忽视开发者体验以及不恰当使用度量等。

## 第2章 需求及敏捷协作领域实践

### 2.1 业务探索

通过商业模式画布明确目标客户，提出合理解决方案，并探索差异化竞争优势。运用设计思维与用户共情，定义用户问题并探索创新点子。利用影响地图连接业务目标与实现方式，明确行动计划和所需特性。规划产品路线图，确保产品目标与特性开发的时间表和努力相匹配。以最小化可行产品（MVP）为起点，通过“构建-衡量-学习”循环进行快速迭代和优化。利用精益数据分析驱动产品决策，持续改进并满足用户需求。

### 2.2 精益需求

采用条目化的用户故事表达精益需求，确保需求具有3C特征和INVEST原则。通过故事树结构管理产品全量和不同层级的需求，保持需求的层次结构和清晰性。精益需求通常采用2~3层结构，如业务需求-产品需求-工作任务，以确保需求的明确性和可管理性。

### 2.3 实例化需求

使用“假定（Given）-当（When）-那么（Then）”的语言将需求描述为实例，确保需求真实可测且包含非功能性需求。在需求说明中结合实例和领域建模，提高需求的理解和实现效率。

### 2.4 敏捷协作

基于敏捷宣言的价值观和原则进行协作，促进团队高效沟通和协作。敏捷协作在规模为10人左右的小规模敏捷团队中最为有效，有助于提升团队的响应速度和创新能力。

### 2.5 可视化管理

运用波特价值链分析方法，深入剖析研发过程中的基础性与支持性活动。通过价值流图，映射并展示研发过程中价值的流动路径。借助看板，实现产研全流程的直观可视化，便于团队成员快速了解进度和状态。同时，运用累积流图等统计分析工具，深入挖掘看板中的关键信息，为决策和优化提供依据。

### 2.6 规模化敏捷交付

围绕价值流，我们组建了一支由多个小规模敏捷团队构成的大规模敏捷团队。规模化敏捷架构的核心任务是解耦，力求去除不必要的规模化元素。对于不频繁、影响大、实施时间长的举措，我们会在管理层决策后，将其拆解成更小、更易于管理的需求。在规模化的敏捷流程中，我们强调节奏的一致性，确保全员同步启动、计划和迭代交付。同时，我们需要一个端到端的敏捷DevOps平台，以支持多个小规模敏捷团队的协作体验，以及大型解决方案的持续交付。

## 第3章 开发领域实践

### 3.1 分支模型

分支模型是配置管理的核心组成部分，对于团队协作管理至关重要。常见的分支模型包括主干分支开发模型和特性分支开发模型。团队应根据业务特点、团队规模及当前阶段选择最适合的分支模型，形成符合自身的最佳实践。没有绝对理想的分支模型，只有最适合团队现状和上下文环境的模型。

### 3.2 本地开发

高效本地开发的宗旨在于提升开发者的编码效能，减少阻碍和不必要的干扰。建立规范化和自动化的研发流程是实现高效开发的关键，也是持续优化和投入的重点。在构建高效开发环境时，我们遵循以下原则：建立符合团队特点的研发规范；利用资源换取时间；实现服务化、自助式的环境获取；确保环境的一体化和一致性。

### 3.3 云开发

云开发是解决本地资源不足、开发环境差异以及云原生环境下开发挑战的有效手段。云开发涉及共享云端环境、基于K8s Namespace的隔离开发环境和基于Istio Mesh的逻辑隔离开发环境。此外，通过容器应用热加载，我们可以实现云端开发编码的实时生效，进一步提高开发效率。

### 3.4 代码平审

代码评审是质量内建的核心实践之一，体现了工程师文化的基石。不同类型的代码评审实践具有各自的特点，适用于不同的上下文环境。在进行代码讲审时，我们既要关注业务价值的正确交付，也要考虑代码的长期可维护性。

### 3.5 单元测试

单元测试是测试左移的关键实践之一，为高质量测试策略奠定了基础。我们应同等对待单元测试代码与业务代码，关注其可维护性、测试有效性、执行时间和稳定性。单元测试的推进是一项长期投资，需要结合团队现状，循序渐进地持续提升。

### 3.6 代码扫描

代码扫描能够在早期发现代码问题，从而降低解决成本。修正代码扫描发现的问题与修复代码缺陷类似，都需要通过回归测试来验证。在实施代码扫描时，我们应保持灵活和因地制宜的态度，避免盲目引入导致团队负担增加。

### 3.7 编译构建

优秀的团队应每天自动化完成最新的代码构建并发布到测试平台。针对传统本地编译构建的问题，业界已发展出分布式构建、编译缓存和云端构建等技术。在选择编译构建平台时，我们应关注其接入成本，尽量实现无侵入式接入。编译构建的优化是一个不断迭代的过程，而编译过程的可视化则为持续优化提供了数据支持。

### 3.8 架构设计

架构设计的质量对需求、开发、测试和运维等大部分研发效能领域的提升起着决定性作用。架构设计的初衷不是为了满足模式和原则，而是在深入理解和分析业务目标后，设计或选取与目标高度关联的最优解。

### 3.9 低代码应用

低代码，作为一种可视化的软件开发方式，有效缩短了研发周期，并显著降低了研发成本。这种方法中，可视化流程和可视化改丰机是常用的技术手段。在国机代配程节点中，植入与配置质量卡点，是推动质量左移和右移的关键实践。

### 3.10测试驱动开发

测试驱动开发是一种强调测试在先、编码在后的开发实践。它确保了代码的微观质量，真正实现了质量内建的目标。测试驱动开发原则包括：先写测试代码，再写产品代码；只允许编写能够导致失败的单元测试；以及只允许编写刚好能够导致一个失败的单元测试过的产品代码。

## 第4章 测试领域实践

### 4.1 测试环境管理

稳定且完备的测试环境是自动化任务执行的重要保障。测试环境管理不仅是某个部门或角色的责任，每个人都既是测试环境的使用者，也是其建设者。通过基准环境和功能环境的配合使用，一套微服务环境可以满足多个需求并行测试的场景。同时，测试环境需要全生命周期的完整管理手段，包括环境的创建、更新、访问、销毁、校验、度量等。

### 4.2 自动化验收测试

在选择自动化框架时，除了考虑框架的技术特性外，还需充分考虑团队的人员能力。自动化验收测试用例需持续维护，以确保其高稳定性和可用性。尽管自动化验收测试在现阶段不能完全替代手工测试，但它仍然是提升测试效率和质量的重要手段。

### 4.3 自动化接口测试

在当前的测试体系中，接口测试的重要性不言而喻。自动化接口测试涵盖了协议客户端模拟、接口逻辑模拟、数据驱动、自动化执行、断言操作、关键字驱动、测试替身等关键技术。同时，关注缺陷自动提交和误报缺陷自动过滤是提高测试效率和准确性的关键方向。

### 4.4 测试数据管理

测试数据管理需要在评估投入产出比的基础上进行，不是所有测试数据都需要提前准备，也不是所有测试数据都无法准备。测试数据管理需要与测试工作紧密结合，按需建设，并及时维护和更新。测试数据产生的价值是衡量测试数据管理效果的唯一标准。

### 4.5 性能测试

性能测试是评估系统容量大小、响应速度和并发能力的重要手段。性能测试实践包括测试环境、测试数据、测试策略、测试工具、测试结果五个要素。性能测试可以按照单机评估、集群评估、扩缩容对比三种方式开展。

### 4.6 全链路测试

全链路压测中的链路可分为调用链路和业务链路两种形式。调用链路的压测主要应用于单个系统或业务场景的容量评估；而业务链路压测则是对多个有业务关联的场景所产生的调用链路集合进行评估。全链路压测是一种工程实践，而非单指平台建设。流量录制回放技术丰富了全链路压测实践的手段，可在此基础上根据业务场景对录制的数据进行修正和验证。

### 4.7 安全测试

安全风险把控是全体参与方的共同责任，而非某个部门或角色的专属任务。安全测试需要融入研发流程的各个环节，以一种潜移默化的方式发挥作用。通过安全测试，我们可以及时发现和修复潜在的安全风险，从而确保产品的稳定性和可靠性。

### 4.8 精准测试

传统黑盒测试存在诸多挑战，如测试过程不可靠、测试范围不明确、效果评估模糊且滞后等。而精准测试则从软件系统的逻辑、变更、覆盖三个底层关注点进行分析和度量。通过精准测试，我们可以更准确地找到发生变更的代码段，监控测试执行过程中的覆盖率，从而指导测试用例的选取，实现变更代码的最大覆盖度。

### 4.9 测试中台

测试中台旨在赋能开发人员开展高效率、高质量的测试工作。通过全局架构设计，测试中台为提升测试效率提供了更清晰、更直观的全局视野。测试中台包括测试执行服务、测试数据服务、测试执行环境等关键组件，为开发人员提供全面、高效的测试支持。

## 第5章 CI / CD 领域实践

### 5.1 持续集成

持续集成强调频繁地将代码改动集成到共享分支，并进行自动化测试。通过构建流水线的引入，确保各步骤迅速完成，及时发现并修复集成问题。实施持续集成时，需避免教条主义，因地制宜，以满足团队需求。

### 5.2 持续交付

持续交付旨在以安全、快速、可持续的方式将变更交付至生产环境或用户手中。它是持续集成的延伸，强调版本控制、自动化、快速执行和及时修复。其核心目标是缩短开发到发布的时间，提高发布的可靠性。逐特性发布的集成方式，是对特性发布速度极致追求的体现。

### 5.3 变更管理

变更管理确保软件开发中的所有变更均被记录和追溯。遵循可灰度、可监控、可回滚的三大原则，对基础设施、代码基线、配置项、依赖项、数据库及生产发布等变更进行有效管理。最佳实践包括自动化变更过程、建立评审机制、确保可追溯性、灰度发布和回滚能力。

### 5.4 部署自动化

部署自动化允许用户通过一键式操作将软件部署至测试和生产环境，全程自动化，无需手工干预。每个环境使用相同的部署流程，确保软件包的一致性。利用版本控制的代码仓库，便于创建特定状态的环境。

### 5.5 制品管理

制品是软件资产的关键部分，存放在制品库中以防损坏或丢失，同时便于查找和追溯。除了制品本身，还需管理其元数据，如质量等级和与源代码的关联关系。制品仓库是企业软件资产管理平台，为合规、安全使用第三方组件提供保障。

### 5.6 发布策略

理解和制定发布策略的前提是明确部署与发布的差异。没有通用的最佳策略，只有最适合场景的策略。选择发布策略时，需综合考虑技术和业务因素。常见的策略包括停机部署、滚动更新、蓝绿部署等。实现这些策略需关注负载均衡、不可变基础设施等技术要点。

### 5.7 数据库变更

数据开发人员应像应用开发人员一样管理数据库资产，确保数据库架构具备演进能力。重视数据库Schema脚本的变更管理，实施版本控制和发布流程。在生产环境中进行变更时，确保升级迁移的安全可靠以及数据的保护和隐私。

### 5.8 配置参数管理

系统配置参数和业务配置参数均应得到妥善管理。根据配置参数的性质和适用场景，选择合适的管理方法。若配置参数随源代码演进，建议与源代码一同纳入集成发布流程；若配置参数值随环境变化，则无需与源代码同步。

## 第6章 运维领域实践

### 6.1 云原生基础设施

云原生不仅是一种技术，更是一种思想，融合了技术与企业管理方法。它为技术创新和流程改进提供了坚实的支撑平台，具备容器化的一致性运行环境、声明式API系统和统一的可观测性方案等核心能力。

### 6.2 可观测性

可观测性涵盖事件日志、链路追踪和聚合指标三个方向。它帮助企业实时监控、分析并诊断复杂系统的运行状态，确保系统的高可用性和稳定性。通过实施可观测性策略，企业能够及时发现问题、快速响应，从而提升系统运维的效率和质量。

### 6.3 全景监控

全景监控，作为一种全面的可观测性解决方案，能够深入洞察系统的运行状况，从而助力企业实现业务的透明化、提升对问题的响应速度，并加强对全局的把控。它涵盖了监控数据采集、传输、存储、可视化、警情评估、监控告警和数据分析等多个关键环节。有效的全景监控不仅能够降低运维风险，还能帮助开发工程师在软件开发和交付过程中提升效能，确保基于监控数据做出正确的决策。

### 6.4 智能运维

结合人工智能技术与传统自动化运维，AIOps（智能运维）大幅提升了运维的效能。其核心关键技术包括数据采集、处理、存储、分析和AIOps算法。在运营保障、成本优化和效率提升三大应用场景中，AIOps展现出了巨大的潜力。常见的算法技术有指标趋势预测、指标聚类、多指标联动关联挖掘等，它们共同为企业的运维工作提供强有力的支持。

### 6.5 混沌工程

混沌工程是一项旨在提升复杂系统稳定性的赋能活动。通过故障注入实验，它增强了各角色之间的协作，从而提高了系统的稳定性。混沌工程不仅分析系统运行和失效模式以了解复杂系统，还通过改进系统稳定性和可观测机制，增强了系统的韧性和故障响应速度。

### 6.6 ChatOps

ChatOps，一种新型智能工作方式，巧妙地连接了人、机器人和工具。它以在线沟通平台为核心，通过机器人与后端服务的无缝对接，实现了高效的工作流程。ChatOps由自动化的流程、聊天室（控制中心）、机器人（连接中心）和基础设施四个主要部分构成。随着技术的发展，ChatOps正逐渐从简单的指令驱动向数据和流程驱动转变。

## 第7章 运营领域实践

运营领域的范畴广泛，通常涵盖了To B、To C、To E和To G四大类。产品上线后，通过精心设计的增长模型，我们可以实现从0-1和1-N两个阶段的有效运营。结合Who、What、When和Where的维度，我们可以制定和推广有针对性的增长策略。一种普适且效果显著的运营策略是采用产品研发官方宣传和业务用户KOL站台相结合的方式，以传递产品的独特价值。在减少人工运营方面，有三个实用的方法：制定详细的产品操作SOP（标准作业程序）、使用产品小助手公用账号进行问题解答，以及设置使用门槛，确保用户通过考试后才能开启账号。

## 第8章 组织和文化领域实践

### 8.1 敏捷组织

敏捷组织致力于将传统的固化等级官僚性结构转变为充满生命力的有机体。它不仅关乎单点能力，而是涉及到战略、架构、流程、人员和技术等多个层面的系统工程。实现敏捷组织的落地需要遵循一个核心原则、两个必要支柱、三种协作模式以及四类团队类型。

### 8.2 故障复盘

团队的复盘能力直接决定了其进步空间的大小。在复杂系统中，由于高网络密度和强耦合性，故障往往难以完全避免。然而，关键在于认识到故障只是表象，背后的技术和管理问题才是根本所在。我们需要包容失败，但绝不允许犯错。在复盘过程中，应避免仅关注唯一根因。

### 8.3 工程师文化

文化对于企业的成败至关重要。建立符合公司特点和文化体系的核心价值观，对于公司的健康发展具有重大意义。优秀工程师文化通常具备平等、高效和创新等共性特征。而这些价值观的塑造和传承，是实现工程师文化的基石和核心。工程师文化，虽重要，却非企业成功的唯一因素，我们不应过度神化。实际上，工程师文化同样需要持续的“维护”与滋养。

### 第9章 研发效能平台的“双流”模型

在多个工具平台间频繁切换，为研发人员带来研发流程上的巨大挑战。而“一站式”与“一键式”的研发效能平台则能有效降低这种认知负荷，让研发人员得以更专注于创造真正的价值，而非陷入琐碎的事务性工作。这种“双流”模型确保了需求价值流与研发工作流之间的高效协同与自动化的流畅联动。

## 第10章 自研工具体系

### 10.1敏捷协作域工具

敏捷协作域工具旨在满足企业的敏捷协作需求，推动敏捷文化的生长，使敏捷实践得以真正落地。其中，涵盖了规划与过程管理、需求管理、测试管理、文档协同与知识库，以及度量与持续改进等关键环节，共同构成了敏捷协作的全景图。而产业研发需求工作流的灵活协同，则确保了需求的逐层拆解与自动化的紧密关联。迭代管理则支持产品制和项目制两大模式，满足不同发布节奏的需求。

### 10.2 代码域工具
代码域工具是软件开发工程师的核心装备，其能力水平直接反映了公司的软件工程实力与工程影响力。这些工具不仅限于开发工具（DevTools），更应朝着研发基础设施（Devlnfra）的方向迈进。

### 10.3 测试域工具

测试域工具涵盖了测试过程管理与测试资产管理两大维度，需要独立设计。测试流水线与研发流水线的紧密协同，通过测试左移和右移的实践，实现了全链路的测试能力。而自动化测试执行体系，则是提升研发效能的关键。

### 10.4 CI/CD域工具

软件交付效率的提升来源于领域内的执行效率和领域间的协同效率，实现了从人驱动工具到工具驱动人的转变。CI/CD域工具的价值体现在过程协同、信息协同和组织协同三个方面，尤其在规模越大的情况下，其效果越为显著。而其六大通用设计原则，可以说是必不可少的。对于CI/CD域工具来说，其未来的发展方向是云原生和价值流交付平台，这是不可逆转的趋势。

### 10.5 运维域工具
在构建运维平台时，我们需要考虑其通用性，同时兼顾可靠性、可重用性和可重复性，以降低自动化技术的门槛和减少重复建设的成本。而X-Ops理念，已在DevOps、DataOps、AlOps、MLOps、GitOps和CloudOps等实践中得到广泛认可并落地。对于运维域工具的发展，我们有五大趋势可以期待：云原生化、低代码化、移动端能力、开发和运维的深度融合，以及运维服务化与智能化。

### 10.6 移动研发平台

移动研发平台的宗旨在于加速端到端的研发交付效率，提升App的线上品质，并降低代码开发成本。从用户场景出发，移动研发平台涵盖了移动研发、质量、应用性能监控、低代码、Web研发、项目管理等六大建设方向。而未来，我们可以期待移动研发平台的三大发展方向：云IDE化、跨端开发、测试左移。

### 10.7 一体化协同平台

单点工具的串联无法有效解决研发效能的“痛点”，因此，企业需要通过一体化协同平台来提高端到端的价值流动效率。一体化协同平台的价值在于最大化软件工程理念的落地，实现数字化研发管理，以及提供沉浸式的研发体验。在集成一体化协同平台时，我们需要评估闭环效率杠杆，明确集成的边界和深度。

### 10.8 代码智能化工具

代码智能化工具主要依赖代码静态分析、编译器的前端技术等手段，并结合AI、机器学习和深度学习等技术。在使用这些工具时，我们需要考虑代码的语法和语义特征，如AST、定义-引用关系、函数调用关系、控制流、数据流等。通过智能语言服务通用框架SLSCF，我们可以在代码提交前、提交中和提交后各环节实现代码智能化的实践。其中，代码补全、搜索和推荐是智能化辅助研发效率提升的三大场景。

## 第11章 开源工具集成

合理采用开源工具，企业内部能够避免重复造轮，但这也可能引发工具孤岛和碎片化研发的问题。开源DevOps工具的选型和导入，不仅涉及学习调研成本，还涉及工具间的集成和切换问题。因此，针对开源工具的选型与导入，需要具体问题具体分析，难以给出一刀切、适合所有场景的建议。为了有效地解决这些问题，我们可以借鉴分层“松耦合”的方式，包括能力底座、工具适配层和工具集成，这样的设计方案有助于实现更高效的工具集成。

## 第12章 研发效能度量

### 12.1 度量框架

研发效能度量框架可以概括为E3I框架。虽然软件研发效能度量的内涵和外延丰富多样，但我们可以提纲挈领地概括其要义。其内涵主要归结为效果（Effectiveness）、效率（Efficiency）和卓越能力（Excellence）这三个“E”。外延则主要归类为交付价值、交付速率、交付质量、交付成本和交付能力这五个认知域。为了提升软件研发效能，我们可以采用度量（Measure）-分析（Analyze）-回顾（Review）-改进（Improve）的MARI循环。

### 12.2 指标体系

度量指标体系的设计必须紧密围绕团队研发效能度量的目标。它是一系列可量化研发效能水平的指标集合，需要使用多个指标从不同维度来综合评估与分析。合理的指标体系设计，必须能够准确反映出研发过程中的问题或待改进点。效能指标和效能度量应该引导研发团队做出真正能解决问题的行为，而不仅仅是追求数据上的好看。

### 12.3效能分析

效能分析是通过科学的方法，深入分析数据与研发活动的因果和关联关系，进而找到研发"痛点"、可改进项和值得总结的经验效能诊断分析可以使用判定表、趋势分析等方法，效能优化、问题分析可以使用逻辑树、下钻分析、相关性分析等方法要进行系统性的效能分析，不能陷入局部思维，避免陷于"数字游戏""反映部分事实"等困境要注重效能分析的持续性，持续反思与优化，以确保在向效能提升目标靠近。

### 12.4 度量平台

度量平台的设计可以拆分成数据采集、数据计算、数据分析和展现几层组件为满足不同数据源的采集和计算分析，在数据接入之前就需要设计统一的数据抽象和关联映射机制以面向对象的思路来设计画像数据和指标体系，避免单纯的指标堆积通过多维度数据分析挖掘对象以及指标之间的变化规律，从而找到影响效能的关键因素。

### 12.5 专项度量分析

#### 12.5.1 需求价值流分析

需求价值流分析的五个核心度量指标分别是流动时间、流动速率、流动负载、流动效率、流动分布将五个核心度量指标结合在一起可以刻画需求交付的完整过程，回答关于交付效率的本质问题通过价值流分析，可以发现研发过程隐藏的问题和瓶颈点，采取针对性的行动可以有效促进效能提升需求价值流分析的前提是数据的准确性，需要通过管理或者自动化技术手段给予保障，这样分析的结果才能反应实际情况。

#### 12.5.2 代码的度量分析

代码分析可以补足对研发产出侧而非过程侧的度量，极大提升度量体系的完整性和有效性。作为代码度量的典型代表，"开发当量"可以反映研发产出的复杂度，在交付速率、交付质量和交付成本等领域都有重要应用缺陷密度、缺陷修复工作量、函数复杂度、函数影响力、代码重复度等其他代码度量指标，对改进工程质量也有重要作用开发者的代码贡献、代码质量、技术经验都能在代码中体现，也能通过代码分析进行度量。

#### 12.5.3 代码评审度量分析
从CR发起、CR评论、CR颗粒、评审状态以及评审投入等量化指标设计中，可以发现代码评审流程中的问题并改善其活动的开展在进行代码评审数据分析时，可以采用趋势分析、对比分析、分布分析、结构分析、漏斗分析等方法。Python自动化数据分析是一个成本比较低，适用于需要大批量复制的一个不错的数据分析实施工具。

### 12.6 度量的成功要素

研发效能度量要坚持数据驱动和实验精神，让研发效能可量化、可分析、可提升模式，避免"踩坑"才能走得更远 "成功大都相似，失败各有不同"，认清效能度量的十大反度量体系建设需要综合考虑度量的用户场景、度量的指标体系、度量的模型设计、度量的产品建设、度量的运作模式研发效能度量是复杂的系统性工程，顶层规划很重要，需要把度量引导到正确的方向上来。
