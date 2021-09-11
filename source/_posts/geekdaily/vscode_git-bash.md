---
title: 【极客日常】2021新版本VSCode设置git-bash为终端的方法
date: 2021/09/11 11:50:22
categories:
- 极客日常
tags:
- VSCode
- git
- shell
- VSCode设置
- git-bash
---

截至2021.9，不知道哪天更新了vscode，发现默认的终端从以前的git-bash变成了powershell，笔者用的windows电脑，于是乎要解决这个问题，把powershell变回git-bash。

打开settings，发现以前的`terminal.integrated.shell.windows`设置已经失效，不能再用。在settings的图形界面查看shell设置，默认的选项变成了`PowerShell`、`Command Prompt`和`Javascript Debug Terminal`，不能直接指定git-bash路径。

经过一番查找，发现[官方文档](https://code.visualstudio.com/docs/editor/integrated-terminal)已经说明可以通过设置`terminal.integrated.profiles.windows`的方法，增加一个shell选项，从而达到目的。于是我们可以在`settings`里添加一个`git-bash`选项：

```json
"terminal.integrated.profiles.windows": {
    "git-bash": {
        "path": "X:\\GIT_ROOT\\bin\\bash.exe"
    }
}
```

然后在shell选项里就能选择git-bash了。试试看吧~
