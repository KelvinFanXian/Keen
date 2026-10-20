<p align="center">
  <img src="Resources/AppIcon.png" width="180" alt="Keen Logo">
</p>

<h1 align="center">Keen</h1>

<p align="center">Read with Clarity.</p>

<p align="center">一款轻量、原生、只读的 macOS Markdown 阅读器。</p>

Keen 面向使用 Claude Code、Codex 等 Agent 开发软件的工程师。它专注于舒适地阅读 Agent 持续生成和更新的 Markdown 技术文档，而不是成为编辑器、IDE 或知识库。

> Keen 正处于 MVP 开发阶段。当前版本用于本地构建和交互验证。

## 当前能力

- 原生 SwiftUI / AppKit 三栏界面
- 按需加载的 Markdown 文件树
- 基于 Apple `swift-markdown` AST 的只读 HTML 渲染
- H1～H6 文档大纲和双向章节定位
- 文档内 Markdown 链接直接打开目标文档并支持章节锚点
- Mermaid 本地按需渲染、缩放、平移与适应宽度
- 章节源码行号与 `文件路径:行号` 复制
- 多文档会话与预览：单击文件树预览、双击固定；通过菜单或快捷键切换、关闭其它与关闭右侧
- 文件修改事件监听和自动刷新
- 当前文件绝对路径复制
- 固定浅色 Swiss 正文排版；保留字号和阅读宽度设置
- 专注阅读模式可一键隐藏文件树与大纲（`⌘J`）
- Markdown 文件或文件夹拖放打开

## 系统要求

- macOS 15.0 或更高版本
- Xcode 27 或兼容的 Swift 6.2+ 工具链

## 构建与运行

```bash
make build   # Debug 构建
make test    # 运行测试
make app     # 生成并临时签名 Keen.app
make run     # 构建并启动
```

生成的应用位于 `.build/app/Keen.app`。未配置 Apple Development 证书时，脚本使用 ad-hoc 签名，适合本机运行。

## 命令行打开工作区

将构建好的应用安装为 `/Applications/Keen.app`，再把仓库中的命令行入口加入 PATH：

```bash
ln -s "$(pwd)/scripts/keen" "$HOME/.local/bin/keen"
keen .                 # 打开当前目录
keen /path/to/project  # 打开指定目录
```

命令支持相对路径、绝对路径和带空格的路径；应用已经运行时会切换到指定工作区。若应用安装在别处，可设置 `KEEN_APP_PATH` 指向对应的 `.app`。命令只打开目录，不修改其中的文件。

## 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 打开文件 | `⌘O` |
| 打开文件夹 | `⇧⌘O` |
| 最近打开的文件 / 工作区文件搜索 | `⌘E` / `⇧⌘F` |
| 页面查找 | `⌘F` |
| 后退 / 前进 | `⌘[` / `⌘]` |
| 上一个 / 下一个标签页 | `⌃⇧Tab` / `⌃Tab` |
| 切换到第 1–9 个标签页 | `⌘1`–`⌘9` |
| 关闭当前标签页 | `⌘W` |
| 固定当前预览文件 | `⌥⌘P` |
| 显示或隐藏文件侧栏 / 大纲 | `⌘B` / `⌘L` |
| 专注阅读 | `⌘J` |
| 切换全屏 | `⌃⌘F` |
| 启用或关闭 Vim 风格阅读导航 | `⌘K` |
| 复制当前文件绝对路径 | `⌥⌘C` |
| 增大 / 减小字号 | `⌘+` / `⌘-` |
| 恢复默认字号 | `⌘0` |

Vim 风格阅读导航默认关闭，开启后在正文区响应：`j`/`k` 逐段滚动、`⌃D`/`⌃U` 半页滚动、`⌃F`/`⌃B` 整页滚动、`gg`/`G` 页首/页尾、`gt`/`gT` 切换标签、`⌃O`/`⌃I` 后退/前进、`/` 打开页面查找、`n`/`N` 跳转下一个/上一个查找结果。文件树获得焦点时，`j/k` 移动光标、`h/l` 收起/展开目录、`Space` 打开文件。它不会进入编辑模式，也不会修改文档；搜索框和其它输入控件不受影响。常用视图切换优先使用双键组合，保留 macOS 惯用的全屏与搜索键位。

未全屏时，阅读区顶部显示多文件标签，可单击切换和关闭；全屏时隐藏。也可以通过「导航 → 打开的文件」或标签快捷键切换。固定预览、关闭其它文件、关闭右侧文件也在「导航」菜单中。

应用内容区只有文件树、正文、大纲三列。未全屏时中间顶部是多标签栏，右上角的文件侧栏与大纲按钮常显；隐藏大纲后，按钮仍留在标签栏右端，方便重新打开。全屏时页面内标签栏隐藏，两按钮移到系统标题栏，三列内容直接到顶；常用操作也可通过 macOS 菜单栏和快捷键完成。

## 项目结构

```text
Sources/Keen/          原生 macOS 应用源码
Tests/KeenTests/       Markdown 渲染等自动化测试
Resources/             App 图标和 Info.plist
scripts/               本地 .app 打包脚本
docs/REQUIREMENTS.md   产品边界和验收规范
docs/DEVELOPMENT.md    阶段进度、验证记录和后续计划
docs/ADJUSTMENTS.md    交互调整需求、状态和验收口径
docs/DESIGN_DECISIONS.md  稳定的产品与交互决策
docs/ARCHITECTURE.md   模块边界、安全策略和数据流
docs/TEST_REPORT.md    已执行的功能测试与手工验收清单
docs/PERFORMANCE.md    性能目标、口径与实测记录
docs/KNOWN_ISSUES.md   当前限制和待解决问题
docs/UI_WALK.md        真实界面走查记录与视觉回归项
```

## 产品边界

Keen 不提供 Markdown 编辑、AI 对话、Agent 管理、Git 客户端、云同步、账号、插件或知识库能力。

详细要求见 [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)，当前进度见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)，后续交互调整见 [docs/ADJUSTMENTS.md](docs/ADJUSTMENTS.md)，已知问题见 [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)。

作者：范显

Mermaid 使用 MIT License，许可证随资源保存在 `Sources/Keen/Resources/vendor/Mermaid-LICENSE`。
