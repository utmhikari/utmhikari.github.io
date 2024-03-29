---
title: 【测试人生】数据同步和迁移的变更注意事项
date: 2023/12/09 22:31:50
categories:
- 测试人生
tags:
- 数据变更
- 数据迁移
- 变更风险
- 质量管理
- 质量保障
---

数据同步或者迁移操作也算是线上数据变更的一种类型。由于涉及的数据量非常大，一旦发生故障，会直接影响线上业务，并且较难止损。从变更风险管控的角度考虑，数据同步或迁移操作也需要走合理的发布窗口，并且在操作前也需要做足够的影响分析。本文就来聊一下数据同步和迁移的变更期间注意事项。

数据同步按照持续状态的不同可以分为一次性同步跟持续性同步。从质量保障的角度，要降低持续性同步的风险，需要额外考虑数据跟组件性能的监控，其它方面的考虑两者没有太大的差别。数据同步的操作手法也有很多种，既可以通过搭建中间件，实现一个导入binlog到MQ然后再导到其它存储的通路，也可以通过自建业务服务，通过批量刷数的方式主动导入大量数据。对于后者，在[以前的文章](https://utmhikari.top/2023/07/09/testlife/data_wash_risk/)当中已经提到了一些通用的风险点，但如果考虑到数据同步的需要，还会有一些额外的考量。

<!-- more -->

第一块是压力，数据同步的压力相比于一般修数是更加大的，源存储有读的压力，而目标存储有写的压力，并且由于一般读操作可能会分散到多个存储节点，写压力对于单点存储的影响会更大，因此需要重点考虑目标节点当前的QPS情况，选择一个相对合适的数字。

第二块的考量点是同步数据的筛选和转化。通常如果涉及到异构数据存储，同步链路上需要执行数据转化的服务节点，这些节点也会承受一定的压力。如果服务节点的QPS过高，可能会影响服务节点连带的一些服务，或者也有可能导致服务节点注册的网关触发限流，这样就有业务不可用的风险。同时，数据转化本身的代码逻辑也需要保证健壮性，如果触发了corner-case导致服务报错，也有可能影响甚至阻塞数据同步。

第三块的考量点是数据校验。尤其针对批量调用服务接口导入数据的情况，需要通过一定的机制去验证数据的正确性，保证同步的数据生效并对符合业务需求表现。校验方面，需要补上小时级、日级的数据对账；发布过程本身，也需要保证有阶段性的灰度过程，并尽可能随机遴选数据，确保全量发布前数据验证无误。

最后再回到压力。这块讨论的是数据同步已经在线上稳定运行时，其它变更需要考虑到线上已有的数据同步链路。好比说DB数据的增量持续性同步，如果线上有大批量的修改数据，那么就会有可能导致潜在的数据同步链路因为突然的压力发生阻塞，影响某些业务可用性。要解决这个问题，需要梳理变更操作涉及的DB，以及DB涉及的数据同步链路，通过小流量灰度的方式初步检测压力状况如何，再逐步地修改并发参数，找到最合适的变更方式。
