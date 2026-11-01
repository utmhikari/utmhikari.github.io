# AGENT.md — HiKariのTechLab 项目 Harness

本文件是本仓库所有 Agent 的工作约定。开始任何任务前先读本文件；写博客、改文章或调整写作风格时，还必须完整阅读 `.qoder/skills/blog-writer/SKILL.md`（写作规范以该文件为准）。与用户沟通使用中文。

## 1. 项目定位

- 基于 Hexo 3.9.0 的中文技术博客「HiKariのTechLab（光の技术屋）」
- 线上地址：https://utmhikari.top
- 源码分支：`hexo`；构建产物由 `hexo deploy` 推送到同仓库 `master` 分支（GitHub Pages）
- 主题：`themes/next`（NexT 7.0.1，Gemini scheme），已深度定制，直接维护主题源码
- 内容：`source/_posts/` 下按 15 个分类目录存放的 Markdown 文章

## 2. 关键目录

| 路径 | 用途 |
|---|---|
| `source/_posts/<分类目录>/` | 博文源文件 |
| `source/uploads/<分类目录>/<文章文件名>/` | 文章配图 |
| `source/about/`、`source/categories/`、`source/tags/` | 独立页面 |
| `themes/next/` | 主题源码与定制（模板、样式、脚本） |
| `scripts/` | Hexo 扩展脚本 |
| `_config.yml` | 站点配置 |
| `themes/next/_config.yml` | 主题配置 |
| `deploy.sh` | 一键构建 + 部署脚本 |
| `.qoder/skills/blog-writer/SKILL.md` | 博客写作规范（写文章必读） |
| `tmp/` | 本地临时目录（已忽略，见第 7 节） |

## 3. 环境与构建（硬约束）

Hexo 3.9 在高版本 Node 下会静默产出 0 字节文件，构建必须使用 nvm 中的 Node v12.22.12。Node 12 是 Rosetta x64 进程，其 spawn 的 `/usr/bin/git` 壳子会以 x86_64 启动并崩溃，因此必须把 CommandLineTools 的 arm64 git 放到 PATH 最前。

构建命令：

```zsh
export PATH="$HOME/.nvm/versions/node/v12.22.12/bin:/Library/Developer/CommandLineTools/usr/bin:$PATH"
npx hexo clean
npx hexo generate
```

本地预览：

```zsh
export PATH="$HOME/.nvm/versions/node/v12.22.12/bin:/Library/Developer/CommandLineTools/usr/bin:$PATH"
npx hexo server
```

规则：

- 不要用系统 Node（v22/v24）直接运行 Hexo，也不要把构建命令简化成单独一次 `npx hexo generate`
- 不要升级 Hexo 或插件版本，除非用户明确要求；现有依赖与 Node 12 强绑定
- 只做构建校验时运行 `clean + generate`；`./deploy.sh` 会推送 `master`，属于对外发布操作，执行前必须向用户确认
- `public/`、`db.json`、`.deploy_git/` 均为生成物，不要手工编辑或提交

## 4. 写博客流程

1. 阅读 `.qoder/skills/blog-writer/SKILL.md`，并读同分类的参考文章
2. 选择分类目录与中文分类名：

| 目录 | 分类名 |
|---|---|
| `ainative` | AI原生 |
| `archiart` | 架构艺术 |
| `codegallery` | 代码艺廊 |
| `diymemo` | DIY小记 |
| `easypython` | Easy-Python |
| `gamedev` | 游戏开发 |
| `gameofautotest` | Game-Of-AutoTest |
| `geekdaily` | 极客日常 |
| `githubdiscovery` | GitHub探索 |
| `gofromzero` | 从零单排Golang |
| `hardpython` | Hard-Python |
| `luatalk` | Lua杂谈 |
| `mediumpython` | Medium-Python |
| `pythonnotes` | Python随笔 |
| `testlife` | 测试人生 |

3. 文件名用英文小写 + 下划线，如 `go_error_handling.md`
4. Front matter 规范：

```markdown
---
title: 【分类中文名】具体标题
date: YYYY/MM/DD HH:MM:SS
categories:
- 分类中文名
tags:
- tag1
- tag2
- tag3
- tag4
- tag5
---
```

- `tags` 固定 5 个，中英混合
- 引入段之后、正文之前插入 `<!-- more -->`
- 正文不用加粗（`**text**`），不写"前言/结语"标题
- 中英文混排自然，技术名词保留英文，中英文之间不加空格
- 篇幅、语气、开篇/收束模式、去 AI 味要求严格按 SKILL.md 执行

5. 写完后按第 8 节做构建校验

## 5. 图片与静态资源

- 存放：`source/uploads/<分类目录>/<文章文件名>/<图片名>.png`
- 引用：`![描述](/uploads/<分类目录>/<文章文件名>/<图片名>.png)`
- 文件名英文小写 + 下划线、语义化；扩展名统一小写 `.png`（GitHub Pages 路径大小写敏感）
- 剪贴板/本地图片按 SKILL.md 流程入库，完成后清理临时文件

## 6. 自定义脚本与主题

- `scripts/llms_txt_generator.js`：生成 `llms.txt` 与 `llms-full.txt`，供 AI 检索引擎使用
- `scripts/jsonld.js`：注册 `jsonld` helper，为文章页生成 schema.org BlogPosting JSON-LD（由 `themes/next/layout/post.swig` 调用）
- `scripts/mermaid-codeblock.js`：把 mermaid 代码块转换为 NexT tag；当前 `themes/next/_config.yml` 中 `mermaid.enable: false`
- `scripts/baidu_token.js`：从环境变量 `BAIDU_PUSH_TOKEN` 注入百度推送 token；不要把 token 写回配置文件或提交
- 主题定制集中在 `themes/next/`。修改主题或脚本时保持与 Hexo 3.9 / NexT 7.0.1 兼容，并说明影响范围

## 7. 临时文件

- 所有临时文件（草稿、一次性脚本、截图中间产物、日志、验证输出）一律放在 `tmp/`
- 每次会话开始时，在 `tmp/` 下新建本次会话的独立子目录，命名 `YYYYMMDD-HHMM-<任务简述>`，如 `tmp/20261031-0930-blog-ai-agent/`
- 本次会话产生的所有临时文件都放进该子目录，不要在 `tmp/` 根目录直接生成文件
- 不要把临时文件散落到仓库根目录、`source/` 或 `themes/` 下
- `tmp/` 及其子目录已在 `.gitignore` 中忽略，不要提交；任务结束后按需清理本次会话的子目录
- 不要提交 `node_modules/`、`public/`、`db.json`、`.deploy*/`、密钥或 token

## 8. 完成前检查

- 文章类改动：
  - front matter 完整，`tags` 为 5 个
  - `<!-- more -->` 位置正确
  - 图片路径与文件名大小写完全一致
  - 正文无加粗、无 AI 味表达（按 SKILL.md 自检）
- 站点类改动：
  - 使用 Node 12 环境执行 `hexo clean && hexo generate` 通过，生成文件非空
  - 抽查相关页面输出正常
- 仓库卫生：
  - `git status` 中无 `tmp/`、生成物、密钥
  - 只改动本次任务相关文件

## 9. Git 与发布

- 开发在 `hexo` 分支进行；`master` 是部署产物分支，不手工修改
- 提交信息沿用现有风格：`fix: xxx`、`update YYYY.MM`、`add xxx`、`refactor: xxx` 等，简洁说明意图
- `.qoder/` 与 `.vscode/` 属于仓库内容，随源码提交，不要重新加入 `.gitignore`
- 发布流程：`./deploy.sh`（`clean → generate → deploy`），会推送到 `git@github.com:utmhikari/utmhikari.github.io.git` 的 `master`，执行前需用户确认
