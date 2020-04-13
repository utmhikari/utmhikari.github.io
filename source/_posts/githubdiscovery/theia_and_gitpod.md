---
title: 【GitHub探索】Eclipse Theia & Gitpod——云端IDE尝鲜
date: 2020/04/13 15:53:13
categories:
- GitHub探索
tags:
- eclipse theia
- gitpod
- cloud IDE
- vscode
- 研发效能
---

本月，[eclipse theia](https://github.com/eclipse-theia/theia)发布了1.0版本。作为一个云端/桌面IDE框架，并且顶着eclipse foundation的名声，theia在github上受到万众瞩目。因此笔者决定上手eclipse theia，提前品尝一下云端IDE的滋味。

笔者选择了[gitpod](https://www.gitpod.io/)而非本地docker作为theia的实验对象，这是因为gitpod本身就是theia的扩展版，并且支持github/gitlab上的项目导入，相当于云端github/gitlab项目的IDE，这样就可以实现在theia中启动一个theia项目，一探其中究竟。

登录gitpod，选择theia项目。项目的预设中会自动构建并在容器的3000端口启动theia。点击右侧的preview，就可以在gitpod的theia中打开原生的theia网页。当然也可以利用gitpod的open in browser方法，在自己浏览器的新标签页中打开原生的theia。

<!-- more -->

![Gitpod中打开theia](/uploads/githubdiscovery/theia_and_gitpod/gitpod.png)

theia是以vscode为基础制作的。我们可以看到原生的theia是不包含插件安装等功能的，而在gitpod中，又基于theia，支持了vsix插件的安装、项目网站构建preview以及支持用户主机与容器交互等一系列的额外功能。插件安装是IDE的核心功能之一，当前的gitpod对此的支持并非完善，以括号染色插件为例，bracket pair colorizer安装不能生效，而rainbow brackets可以生效。插件暂不支持visual studio marketplace检索，但是安装流程能够跑通，且插件可以持久化，应当说。

![rainbow_brackets](/uploads/githubdiscovery/theia_and_gitpod/rainbow_brackets.png)

如果想临时将自己的github项目进行更改，可以将之放在gitpod上进行。具体的方法是，在chrome中安装[gitpod插件](https://chrome.google.com/webstore/detail/gitpod-online-ide/dodmmooeoklaejobgleioelladacbeki)，这样在github网页里，就会额外多出来一个gitpod按钮了。

![gitpod_button](/uploads/githubdiscovery/theia_and_gitpod/gitpod_button.png)

登录gitpod后，点击github项目里的gitpod按钮，gitpod就会生成一个包含该github项目的容器，并启动theia将该项目放到workspace中。用户修改了项目代码后可以直接git push（第一次push时会提示需要授权），从而对github项目进行更新。

由于gitpod作为一项服务，存在收费内容，并且没有容器规格申请的功能业务，IDE周边支持暂不完善，因此仍然不能取代基于本地主机IDE的开发流程。但是cloud IDE终究还是直接提供了环境与部署流程，让开发者专注于业务代码的编写，这块对于开发效率的收益还是非常可观的，因此拭目以待。另外，对于theia，如果业务中有在网页进行编码的需求，采用theia框架扩展开发，可能是一个不错的选择。
