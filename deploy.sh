#!/bin/zsh
# 一键构建 + 部署（本机环境专用，两个 PATH 缺一不可）：
#   1. Hexo 3.9 在高版本 Node 下会静默产出 0 字节文件，构建必须用 nvm 里的 v12.22.12；
#   2. v12 是 x64（Rosetta）进程，它 spawn 的 /usr/bin/git 是 xcrun 壳子，会跟随父进程
#      以 x86_64 启动，而 CommandLineTools 只装了 arm64 库，必然 dlopen 崩溃；
#      把 CLT 的真 git（arm64 原生二进制）顶到 PATH 最前即可绕开壳子。
set -e
export PATH="$HOME/.nvm/versions/node/v12.22.12/bin:/Library/Developer/CommandLineTools/usr/bin:$PATH"
cd "$(dirname "$0")"
npx hexo clean
npx hexo generate
npx hexo deploy
