---
title: 【DIY小记】VMWare设置主机连接到的Ubuntu虚拟机的网络端口
date: 2023/02/05 13:08:17
categories:
- DIY小记
tags:
- 虚拟机
- VMWare
- NAT
- Ubuntu
- DHCP
---

很多同学在自己机器上玩开发的时候，都会用到`VMWare`、`VirtualBox`之类的虚拟OS容器装一个带`GUI`的`Linux OS`，然后在里面另外安装开发工具做开发。这里面遇到的最经典问题，就是比如我在虚拟机里面起了个`MySQL`、`Redis`之类的服务，如果DB的客户端/GUI工具是放在主机里面，不在虚拟机里，那怎么连进去？这个问题，本文提供一种解决方案。

本文采取的虚拟机环境如下：

- 主机：Win11
- 虚拟机容器：VMWare Workstation 16
- 虚拟机：Ubuntu 22.04

首先需要了解到，`VMWare`场景下，我们通常用`NAT`模式新开一个网段来管理虚拟机的网络配置，而虚拟机内部，假设使用`IPV4`，会默认采取`DHCP`机制，自动设置一个`IP`跟相应的网络配置。相关资料可以看这几篇文档：

- [网络中的NAT模式](https://zhuanlan.zhihu.com/p/477147801)
- [DHCP百度百科](https://baike.baidu.com/item/%E5%8A%A8%E6%80%81%E4%B8%BB%E6%9C%BA%E9%85%8D%E7%BD%AE%E5%8D%8F%E8%AE%AE/10778663)

而为了让我们主机能连到虚拟机内部，实际上是满足下面两个条件之一即可：

<!-- more -->

- 主机知道虚拟机的IP，能够直连虚拟机IP
- 主机端口和某个IP的虚拟机端口存在转发映射关系

在本文的场景下，解决方案是第二种。具体配置如下：

首先，在`VMWare`的`编辑`菜单打开`虚拟网络编辑器`，选中用于管理你虚拟机网络的一组虚拟网络（比如是`NAT模式`，名字是`VMnet8`这种）。如果你不确定你的虚拟机是不是`NAT模式`，可以在虚拟机自己的设置里查看`硬件 -> 网络适配器`项目，看是不是`NAT模式`。

选中`NAT模式`虚拟网络配置之后，点击`NAT设置`按钮，即可进入到端口转发映射设置。

![NAT端口设置](/uploads/diymemo/vmware_ubuntu_network/vmnet_nat_config.png)

在其中，我们可以看到`NAT`网络的`子网IP`、`子网掩码`跟`网关IP`，这些信息都会在后续的虚拟机内部设置里用上，而再下面的`端口转发`部分，就是需要我们手动配置的内容。其中包括几项：

- 虚拟机IP地址：虚拟机的IP+端口
- 类型：TCP/UDP，标识什么类型的数据包会被转发
- 主机端口：选定一个主机端口，这样发到主机端口的指定`类型`的数据包会被转发到对应`虚拟机IP地址`

比如虚拟机里面`MySQL`开在`3306`端口，那么`虚拟机IP地址`一项就填`虚拟机IP:3306`，类型填`TCP`，主机端口填一个自己喜欢的即可。

那么这里就遗留另外一个问题：虚拟机IP怎么填？这里的话，以`Ubuntu`为例，由于默认是用`DHCP`机制分配IP，因此IP可能不是固定的。所以我们要做的是，在虚拟机中去设置固定一个IP，然后把这个IP回填到`虚拟机IP地址`一项当中。

在此之前，首先回到`VMWare`的`虚拟网络编辑器`当中，选中刚才`NAT`的一组虚拟网络，点击`DHCP`设置按钮，我们可以看到网络的配置跟`DHCP`的分配地址：

![DHCP设置](/uploads/diymemo/vmware_ubuntu_network/vmnet_dhcp_config.png)

这里我们只需要记住的信息是`起始IP地址`跟`结束IP地址`。我们后面设置虚拟机固定的IP地址时，需要在这个范围之内。

然后进入虚拟机，以笔者用的`Ubuntu 22.04`为例，右上角`开关按钮`点击下拉`Settings`一栏，选择`Network`页签，然后选中当前连接到的网络点`设置图标`进入设置界面。

![Ubuntu网络设置面板](/uploads/diymemo/vmware_ubuntu_network/ubuntu_network_panel.png)

由于先前设置的网络IP都是`IPV4`的，因此在网络选项当中，选中`IPV4`页签，即可开始编辑。编辑的内容如下所示：

![Ubuntu的IPV4设置](/uploads/diymemo/vmware_ubuntu_network/ubuntu_ipv4_config.png)

这里需要编辑几个点：

- `IPV4 Method`：选择`Manual`，表示手动配置
- `Addresses`：地址，这里新建一行
  - `Address`：网段分配的IP地址，也就是我们所要设置的`虚拟机固定IP`，参考上面`DHCP设置`里的网段范围自选一个
  - `Netmask`：子网掩码，在上面`NAT设置`当中有相关信息
  - `Gateway`：网关IP，在上面`NAT设置`当中有相关信息
- `DNS`：DNS的IP，这个场景填写跟`Gateway`一样的即可

弄好之后`Apply`，然后重启虚拟机，就可以试试看行不行了。注意，主机一边，需要发请求到先前`端口转发`设置里的`主机端口`，才能够生效！
