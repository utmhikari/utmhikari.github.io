---
title: 【从零单排Golang】第四话：Win10安装minikube，用client-go部署mongodb
date: 2019/10/03 01:25:52
categories:
- 从零单排Golang
tags:
- Golang
- client-go
- kubernetes
- minikube
- mongodb
---

## 前言

[Github传送门](https://github.com/utmhikari/gofromzero)

提起Golang，就不得不提起[kubernetes](https://kubernetes.io/zh/)，在崇尚上云的今天，kubernetes已成为服务端同学必需掌握之学问。在[第三话](https://utmhikari.github.io/2019/09/01/gofromzero/dockerclient/)中，我们介绍了docker容器，它相当于虚拟操作系统，可以提供环境供各种不同的应用运行，从而实现轻量部署。但要是业务复杂，需要部署较多应用的话，就会遇到许多运维相关的问题，比如：

- 应用关联的资源很多都需要持久化存储，它们的存储空间需要怎样分配及调度呢？
- 不同地域的应用，如何取得相互联系？
- 在应用集群中，如果有一个子应用挂了，该怎么办？
- 。。。

这些问题，单靠docker是解决不了的（也不是docker所要关心的），需要在docker的基础上做更高层次的运维平台才能解决，而kubernetes，就是方案之一。复杂的调度逻辑，都会由kubernetes负责，而运维开发人员则基本只需向kubernetes提供资源及其描述，就能满足运维需求，从而提升工作效率。

既然准备入坑，就需要强行踩下去，因此今天就试试“家中上云”，单机搭建kubernetes，部署一个mongodb数据库。废话不多说，咱们开始吧~

## minikube——在Win10本地搭建kubernetes

<!-- more -->

笔者的电脑为Win10，因此搭建环境的部分，只考虑Win10的情况。

要在本地搭建kubernetes运维平台，首先建议安装docker，直接在官网下载[Docker Desktop](https://www.docker.com/products/docker-desktop)安装即可（提供了日常容器环境+Hyper-V虚拟机功能+kubectl客户端）。在此基础上，安装kubernetes的最好方式是采用官方提供的[minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)工具。minikube提供了一套单节点kubernetes环境（实体为虚拟机），从而使得单机用户也可以享受kubernetes的所有功能。kubernetes厂商为Google，由于众所周知的原因，下载Google资源一直是一个难题。因此，我们需要一个魔改版本——[minikube阿里云版](https://yq.aliyun.com/go/articleRenderRedirect?spm=a2c4e.11153940.0.0.7dd54cecI1P5IU&url=http%3A%2F%2Fkubernetes.oss-cn-hangzhou.aliyuncs.com%2Fminikube%2Freleases%2Fv1.2.0%2Fminikube-windows-amd64.exe)，从而避免科学上网的烦恼。下载好，保存好，记得把minikube根目录加到`PATH环境变量`，这样就能在cmd/powershell里直接运行。

启动minikube之前，需要在Hyper-V创建一个外部的虚拟交换机（开始——Windows管理工具——Hyper-V管理器——虚拟交换机管理器——创建外部虚拟交换机），笔者这边取名为`EXTERNAL_SWITCH`。

minikube启动之后，会在用户文件夹下创建kubernetes配置，而后在Hyper-V中创建一个虚拟机——一个linux系统，里边会自带一个docker+kubernetes的环境。在虚拟机内，我们可以执行docker相关的命令与容器交互，比如查看当前kubernetes相关容器/镜像的信息与状态；而在外边，也就是我们的Win10主机里，因为minikube已经创建了配置，所以我们可以知道kubernetes节点的ip，并且可以用`kubectl`与虚拟机中的kubernetes交互，获得其中状态信息。

启动minikube的方式，建议编写脚本执行：

```powershell
# minikube-start.ps1
minikube start --vm-driver hyperv --hyperv-virtual-switch=EXTERNAL_SWITCH
```

把这个脚本放到minikube.exe同级目录中，就可以直接运行了。如果不能运行的话，一般是powershell执行脚本权限问题，解决方法是用管理员身份打开powershell，然后执行：

```powershell
Set-ExecutionPolicy Unrestricted
```

把执行权限放宽，就好了。

但后面还会有一个问题，普通用户不能创建Hyper-V虚拟机，这个时候只需要在普通用户的powershell中输入`whoami`查看`用户组\用户名`，然后管理员身份打开powershell，输入：

```powershell
net localgroup "Hyper-V Administrators" "用户组\用户名" /add
```

就可以以普通用户身份，输入`minikube-start`，启动minikube虚拟机了。

输入`minikube status`可以查看minikube的状态。如果状态是类似于

```text
host: Running
kubelet: Running
apiserver: Running
kubectl: Correctly Configured: pointing to minikube-vm at 192.168.0.102
```

的话，就说明启动成功了。

要退出minikube，最稳定的方法是`minikube ssh`进入到虚拟机中，然后`sudo poweroff`关闭虚拟机。在笔者电脑上，直接使用`minikube stop`关闭虚拟机有极大概率卡住无法关闭，因此暂不推荐这种方法。

## client-go——用Golang在kubernetes部署mongodb

minikube搭建完毕后，接下来就要实战了——在minikube中部署mongodb。

首先不要急着码，而是要解决以下的问题：

- 数据在哪里存储？（kubernetes的主机是minikube创建的虚拟机，所以在虚拟机里）
- 如何暴露数据库的连接端口？（主机可访问节点，故将mongodb端口转发至节点端口）

对于数据库集群而言，通常会将其封装成一类叫做StatefulSet（副本集）的资源。StatefulSet主要包含Pod的集合，以及和各个Pod关联的PersistentVolumeClaim（PVC）集合。Pod是kubernetes调度的单位，可以理解成单个应用实例，而PVC则是这些Pod各个对应的持久化存储空间的声明。在实际场景中，管理存储空间的人员会预先在kubernetes为许多实在的持久化存储空间打下标记，统称为PersistentVolume（PV），用户则只需要在StatefulSet声明怎样存储（PVC），kubernetes就在内部把各个Pod跟相应的PV绑定起来了。如果一个Pod发生故障，存储空间也不会消失，过后恢复的Pod也会跟原来一样，拥有和原来相同的标识，存储空间也和原来的PV对应。

而在笔者这里的例子里，创建多个数据库以及多个存储空间较为麻烦，因此也有其它的办法——在Pod的资源声明中，我们可以告诉kubernetes要在启动mongodb容器之时，挂载minikube虚拟机里面的一个目录进去存储数据库数据，这样容器宕机之后，数据依然不会消失。

因此，创建mongodb的StatefulSet资源代码如下：

```go
func createMongoStatefulSet(clientset *kubernetes.Clientset) (*appsv1.StatefulSet, error) {
    replicas := int32(1)
    terminationGracePeriodSeconds := int64(10)
    statefulSet := appsv1.StatefulSet{
        ObjectMeta: metav1.ObjectMeta{Name: "mongo"},
        Spec: appsv1.StatefulSetSpec{
            ServiceName: "mongo",
            Replicas:    &replicas,
            Template: v1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: map[string]string{"role": "mongo"},
                },
                Spec: v1.PodSpec{
                    TerminationGracePeriodSeconds: &terminationGracePeriodSeconds,
                    Volumes: []v1.Volume{
                        {
                            Name: "mongo-volume",
                            VolumeSource: v1.VolumeSource{
                                HostPath: &v1.HostPathVolumeSource{Path: "/home/docker/mongo"},
                            },
                        },
                    },
                    Containers: []v1.Container{
                        {
                            Name:         "mongo",
                            Image:        "library/mongo:latest",
                            Command:      []string{"mongod", "--replSet", "rs0", "--bind_ip", "0.0.0.0"},
                            Ports:        []v1.ContainerPort{{ContainerPort: 27017}},
                            VolumeMounts: []v1.VolumeMount{{Name: "mongo-volume", MountPath: "/data/db"}},
                        },
                    },
                },
            },
            Selector: &metav1.LabelSelector{
                MatchLabels: map[string]string{"role": "mongo"},
            },
        },
    }
    return clientset.AppsV1().StatefulSets(defaultNamespace).Create(&statefulSet)
}
```

在这个StatefulSet里面，创建了单副本（replicas=1）的mongo数据库。在副本的Pod模板里，该副本挂载了虚拟机的`/home/docker/mongo`目录（minikube默认用户为docker，mongo目录需要预先创建）到容器里的`/data/db`目录，也就是mongodb数据存储的地方。mongo启动参数要`--bind_ip 0.0.0.0`，从而能够被外部访问。

另外我们也可以看到，这个StatefulSet有一个ServiceName字段，这是因为通过相应的Service，这个StatefulSet才会被集群内其它成员发现。因此，在创建StatefulSet之前，我们其实还需要创建一个相应的Service资源：

```go
func createMongoService(clientset *kubernetes.Clientset) (*v1.Service, error) {
    service := v1.Service{
        ObjectMeta: metav1.ObjectMeta{
            Name:   "mongo",
            Labels: map[string]string{"name": "mongo"},
        },
        Spec: v1.ServiceSpec{
            Type: "NodePort",
            Ports: []v1.ServicePort{
                {
                    Port:       27017,
                    TargetPort: intstr.IntOrString{Type: 0, IntVal: 27017},
                    NodePort:   32017,
                },
            },
            Selector: map[string]string{"role": "mongo"},
        },
    }
    return clientset.CoreV1().Services(defaultNamespace).Create(&service)
}
```

通过NodePort方式，Service资源可以将被服务者的端口（Port）映射到自己的端口（TargetPort），然后再绑定到节点特定的端口（NodePort）。mongodb的默认端口是27017，而通过`minikube ip`，我们也可以知道节点的ip。这样，我们就能在Win10主机里访问minikube里的mongodb了。

把mongodb的Service与StatefulSet资源声明交给kubernetes，它就会自动把mongodb部署起来了。试试吧~

## 总结

kubernetes的难点主要来自于业务经验。技术与业务并行，同志仍需努力！
