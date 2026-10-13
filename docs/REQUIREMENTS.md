# Keen 产品需求与验收规范

> 维护人：范显  
> 最后更新：2026-10-13  
> 状态：Phase 2 MVP 开发中

## 1. 产品定位

Keen 是一款 macOS 15+ 原生、轻量、只读的 Markdown 文档阅读器，产品描述为 **Keen — A Native Markdown Reader for macOS**，理念为 **Read with Clarity.**

它服务于 Agent 驱动的软件开发流程：Agent 写入 Markdown，用户阅读、复制文件或章节位置，再与 Agent 协作。Keen 不取代 IDE、Markdown 编辑器或知识库。

## 2. 核心原则

优先级依次为：Reading First、Native First、Read-Only、Zero Friction、Lightweight、Reliable、Minimalism。

明确不做 Markdown 编辑、AI 对话、Agent 管理、Git 客户端、云同步、账号、插件、知识库、协作、PDF/EPUB 导出和复杂批注。

## 3. 技术约束

- Swift 6、SwiftUI、AppKit、WebKit、Foundation。
- Apple `swift-markdown` 负责 AST 解析，不以正则表达式替代解析器。
- 渲染资源必须随 App 本地打包，离线可用。
- 不使用 Electron、Tauri、Flutter、React、Vue 或常驻 Node.js 服务。
- Markdown 视为不可信输入；原始 HTML 不直接执行，外部链接交给系统浏览器。

## 4. 核心界面

- 左栏：项目目录，只显示文件夹、`.md` 和 `.markdown`，目录按需加载。
- 中栏：多标签只读 Markdown 阅读区。
- 右栏：H1～H6 大纲，可隐藏，点击跳转并跟随正文高亮。
- 使用原生窗口、工具栏、右键菜单、文件选择器和快捷键。

## 5. 文件与导航

- 支持打开单个文件、文件夹、拖放和 Finder Open With。
- 最近工作区、标签页和阅读设置可恢复。
- 文件菜单支持打开、复制绝对路径、复制相对路径、在 Finder 中显示。
- `⌥⌘C` 复制当前文档的纯文本绝对路径。
- 大纲支持复制标题和 `绝对路径:源码行号`；行号来自 Markdown AST source range。

## 6. Markdown 阅读

必须支持标题、段落、列表、引用、表格、任务列表、删除线、图片、链接、代码块、代码高亮、Mermaid、数学公式和 HTML 转义。

相对图片从文档目录解析；相对 Markdown 链接在 Keen 内打开；HTTP(S) 链接交给默认浏览器。代码块支持横向滚动和复制。

## 7. 文件更新

- 使用事件驱动监听，处理写入、原子替换、重命名、删除和恢复。
- 高频更新防抖。
- 刷新不闪屏、不抢焦点并尽量保持章节锚点和相对阅读位置。

## 8. 搜索与阅读设置

- `⌘F` 搜索渲染后的可见文本，支持上一个、下一个、数量和高亮。
- 提供浅色、深色、跟随系统、字号和阅读宽度；不实现复杂主题系统。
- 默认正文 16px、行高 1.75、最大宽度 900px。

## 9. 性能目标

- 普通文档热打开目标小于 300ms。
- 文件修改刷新目标小于 500ms。
- 空闲 CPU 尽量接近 0%。
- 普通文档主进程及 WebContent 内存均需独立测量。
- 文件树按需加载、Mermaid 按需加载、避免为每个标签永久持有独立 WebView。

## 10. 交付与验收

最终交付源码、Xcode 可打开工程、`Keen.app`、README、构建说明、功能测试报告、性能测试报告和已知问题。

每阶段至少执行：

1. `make test`。
2. `make app`。
3. `codesign --verify --deep --strict .build/app/Keen.app`。
4. 用真实软件项目验证文件树、渲染、大纲、复制位置、标签、自动刷新和状态恢复。
5. 涉及产品语义或完成状态变化时同步更新本文档和 `docs/DEVELOPMENT.md`。
