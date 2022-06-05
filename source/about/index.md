---
title: 关于HiKariのTechLab
date: 2022-01-01 11:45:45
type: about
---

## 自我介绍

HiKari，纯粹的技术派，geek，致力于用技术打破不可能的边界

## 兴趣爱好

- 游戏：csgo、皇室战争、skyrim、国产三剑+河洛，各种品类基本都有涉猎
- 体育：羽乒篮足
- 休闲：K麻桌
- 音乐：rock、metal

## 技术栈

语言主python，其它主流的语言多多少少接触过一些。

python写了几个专栏：

- [Easy-Python](https://utmhikari.top/categories/Easy-Python/)：python一些需要掌握的基础内容以及编程思路
- [Medium-Python](https://utmhikari.top/categories/Medium-Python/)：带C源码的python一些源码分析以及冷知识
- [Hard-Python](https://utmhikari.top/categories/Hard-Python/)：连载中，主要对python的关键模块进行分析，平坑之作

领域技术上，偏游戏专项测试跟测试业务效能，也搞过一段时间的运维开发

## 个人经历

### 腾讯-游戏测试

- 测试自动化
  - 技术研发
    - 框架基础是python<->adb<->UE4+UnLua，外加了GAutomator的支持
    - 自动化最关心的还是运行时间量问题。为了保持用例稳定性和自动化实用性做了以下几个事情：
      - gameplay逻辑上UnLua、python根据游戏代码各抽了一层，提升代码复用性，简化用例逻辑编写
      - 截图、录屏、日志解析等周边功能模块全部加上，提升问题排查效率
      - 每个用例逻辑单独目录存放，减少协同开发时的代码冲突问题
      - 框架加了许多技术上的约定，保证其他用例开发者不至于放飞自我= =
  - 业务推进
    - 冒烟测试、全量测试等七七八八各种功能测试业务场景都用上了
  - 文章输出
    - 入门介绍
      - [【测试人生】游戏自动化测试工具GAutomator上手](https://utmhikari.top/2020/05/05/testlife/try_gautomator/)
      - [【测试人生】安卓游戏投屏/录屏利器——scrcpy](https://utmhikari.top/2020/07/18/testlife/scrcpy/)
      - [【极客日常】用Lua编写UE4游戏逻辑——UnLua上手](https://utmhikari.top/2020/08/02/geekdaily/unlua_try/)
    - 心得体会
      - [【测试人生】游戏自动化该怎么做？](https://utmhikari.top/2020/09/06/testlife/game_autotest/)
      - [【测试人生】UE4游戏枪械自动化测试的一些设计](https://utmhikari.top/2021/04/17/testlife/ue4_weapon_autotest/)
      - [【测试人生】副本自动化测试](https://utmhikari.top/2021/05/20/testlife/dungeon_autotest/)
- 测试平台与工具
  - 策划配置测试服务
    - 设计上是分离了策划配置git-repo管理和配置测试服务两方面
      - 除了解耦数据与服务之外，这样设计的好处是能够更方便实现一键对指定版本的配置数据进行测试操作。好比说，一键diff两个版本的excel表格。
      - repo管理服务负责管理多个本地仓库，以及通过自定义脚本以约定格式上传数据到redis。这样的好处是，上传的数据不仅限于excel数据了，编辑器导出数据也能自行支持
      - 配置测试服务接收用户请求从redis上读取数据进行处理，而后返回测试操作结果
    - 功能上提供了一系列策划配置相关测试功能，解决测试效率问题
      - 联表导出：提供了一套类似于mongodb-aggregation的配置化机制
      - 表格对比：excel-diff
      - 数据检索：包含特定类型ID/名称检索、脑图检索、全表搜索之类
    - 文章输出
      - [【测试人生】游戏策划表格检查工具的一种解决方案](https://utmhikari.top/2021/03/06/testlife/table_check/)
      - [【测试人生】为游戏策划与QA量身定制的excel表diff算法](https://utmhikari.top/2020/01/23/testlife/excel_diff/)
      - [【极客日常】用vxe-table展示excel-diff的结果](https://utmhikari.top/2021/05/01/geekdaily/excel_diff_vxe-table/)
      - [【测试人生】游戏策划表格测试工具的技术实现](https://utmhikari.top/2021/06/01/testlife/table_test_tool/)
  - 游戏功能测试PC效率工具
    - 主要通过adb搭桥，PyQt5研发，提供一键式工具集，提升功能测试同学的日常工作效率
      - 装包、推资源、取日志、输命令、转表、投屏、录屏

### 阿里-游戏测试

- 测试工具
  - skynet游戏服框架lua代码覆盖统计
    - 节点用python+lua统计覆盖数据，传输给egg.js后台，后台根据代码预处理数据，mongodb存储最终数据
    - 前台用react进行代码染色展示
    - 文章输出
      - [【Lua杂谈】解锁lua代码覆盖率测试：luacov源码分析](https://utmhikari.top/2019/03/10/luatalk/luacov/)
      - [【测试人生】代码覆盖率测试之代码染色优化——以lua代码覆盖为例](https://utmhikari.top/2020/06/13/testlife/coverage_beautify/)
      - [【Lua杂谈】基于lua的服务端架构——skynet通信原理与源码分析](https://utmhikari.top/2019/10/20/luatalk/skynet/)
  - 安卓app性能统计
    - native binary收集数据，通过ws传输至数据平台后端，前后端socket.io联结，实现前台实时展示性能数据的设计
    - 文章输出
      - [【测试人生】安卓FPS测试详解](https://utmhikari.top/2019/07/13/testlife/android_fps/)
  - excel策划配置工具
    - 实时更新配置数据，提供导表检查、脑图检索、ID->名称翻译等功能
    - 工具在风之大陆用上了，也是因为这个需求顺带开发了[start-fastapi](https://github.com/utmhikari/start-fastapi)，一个专门适合做测试工具后端的web框架
    - 文章输出
      - [【极客日常】解决使用mongodb时同时update多条数据的问题](https://utmhikari.top/2020/01/12/geekdaily/mongo_multi_updatemany/)
      - [【GitHub探索】FastAPI——新一代实用python轻量级Web后端框架](https://utmhikari.top/2020/02/01/githubdiscovery/fastapi/)
- 内部平台
  - 质量管理平台（iOS预审工具）
    - react、java-spring-boot
    - 文章输出
      - [【测试人生】iOS审核&静态扫描二三事](https://utmhikari.top/2019/08/19/testlife/ios_review/)
  - 运维平台（镜像构建）
    - 老三样，golang、k8s、docker。云原生CI什么鬼玩意就都在这会学了些= =
- 项目经验
  - 三国志战略版
  - 风之大陆
