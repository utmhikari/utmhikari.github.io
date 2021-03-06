---
title: 【测试人生】UE4游戏枪械自动化测试的一些设计
date: 2021/04/17 23:54:20
categories:
- 测试人生
tags:
- 游戏测试
- UE4
- 枪械自动化
- 游戏自动化
- 自动化测试
---

在射击类游戏中，不可避免地需要对各种枪械武器进行测试。大多数情况下，枪械种类繁多，人工遍历测试会花非常多的时间，因此引入自动化测试替代人力执行部分冒烟用例，能够增加严重问题提早发现的可能性。枪械测试包括基础行为、伤害、弹道、后坐力等方面，从功能冒烟的角度考虑，基础行为和伤害是需要优先覆盖的部分。因此，本文以UE4引擎下的枪械测试为例，讲解基础行为跟伤害测试的一些设计。

<!-- more -->

对于枪械的基础行为测试，我们可以分为以下几种测试场景：

- 装备武器
  - 切换到特定ID的武器，能正常卸下原来的，装备上新的
- 射击行为
  - 正常开镜射击&关镜
  - 根据枪械类型的不同，能够正常执行单发/三发点射/全自动射击
  - 蹲下、移动、跳跃射击正常
  - 子弹正常消耗
- 装填弹药
  - 手动装填，子弹数量正常
  - 打完弹夹的子弹自动装填，子弹数量正常
- 补充弹药
  - 利用道具或者走到特定的区域，触发弹药补充效果，补充数量正常

针对射击、开镜、移动、装填弹药等行为，因为在游戏中理应会有特定的快捷键绑定，所以在UE4引擎中可以直接调用对应的input逻辑来触发这些行为。

针对子弹数量是否正常的校验，需要了解的是不同的武器需要共同抽象出一些数据model逻辑（这块可以称之为”虚拟武器实例“），子弹数量的计算肯定也会放在内，因此可以通过获取这里面的数据来检查执行行为的前后，弹夹内以及备弹数量是否正常消耗或增加。

类似补充弹药等可能和其它功能模块耦合的行为，实现上就需要结合其他系统的内容，自己抽象一套逻辑了

针对伤害测试，主要的测试场景如下：

- 伤害类型
  - 普通伤害
  - 暴击伤害
- 伤害效果
  - 血量正常减少，与飘字相符
  - 特定的伤害，会产生特定的buff

针对伤害类型，主要看的是普通伤害和暴击伤害，暴击伤害的值需要比普通伤害的高。暴击的实现，假设是爆头的话，可以尝试获取射击对象的SkeletalMesh组件，然后头部socket的当前位置，然后通过rotate的接口使得角色能够朝向并瞄准到射击对象的头部。

针对伤害效果，需要注意的是如果是网游的话，客户端和服务器可能会分开独立计算伤害。客户端伤害数值的表现是飘字，可以通过hook飘字的接口来获取特定设计对象的伤害数据；服务端伤害数值的表现则是射击前后HP的减少。最后需要检测的就是，客户端飘字和服务器里HP减少的量相符。
