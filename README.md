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
- 多文档标签切换
- 文件修改事件监听和自动刷新
- 当前文件绝对路径复制
- 浅色、深色、跟随系统以及字号和阅读宽度设置
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

## 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 打开文件 | `⌘O` |
| 打开文件夹 | `⇧⌘O` |
| 复制当前文件绝对路径 | `⌥⌘C` |
| 增大 / 减小字号 | `⌘+` / `⌘-` |
| 恢复默认字号 | `⌘0` |

## 项目结构

```text
Sources/Keen/          原生 macOS 应用源码
Tests/KeenTests/       Markdown 渲染等自动化测试
Resources/             App 图标和 Info.plist
scripts/               本地 .app 打包脚本
docs/REQUIREMENTS.md   产品边界和验收规范
docs/DEVELOPMENT.md    阶段进度、验证记录和后续计划
docs/ARCHITECTURE.md   模块边界、安全策略和数据流
docs/TEST_REPORT.md    已执行的功能测试与手工验收清单
docs/PERFORMANCE.md    性能目标、口径与实测记录
docs/KNOWN_ISSUES.md   当前限制和待解决问题
docs/UI_WALK.md        真实界面走查记录与视觉回归项
```

## 产品边界

Keen 不提供 Markdown 编辑、AI 对话、Agent 管理、Git 客户端、云同步、账号、插件或知识库能力。

详细要求见 [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)，当前进度见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)，已知问题见 [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)。

作者：范显

Mermaid 使用 MIT License，许可证随资源保存在 `Sources/Keen/Resources/vendor/Mermaid-LICENSE`。
