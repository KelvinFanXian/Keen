# Keen 开发跟进

> 维护人：范显  
> 最后更新：2026-10-13

## 当前状态

| 阶段 | 状态 | 说明 |
| --- | --- | --- |
| Phase 1 初始化 | 已完成 | 工程、模块、窗口、Debug/Release 构建和 App 启动均已验证 |
| Phase 2 核心 MVP | 进行中 | 文件树、Markdown 阅读、大纲、路径复制和可运行 App 已完成基础版，待真实项目交互验收 |
| Phase 3 阅读体验 | 进行中 | Mermaid、本地文档链接、Marked 3 风格阅读版式和首轮 UI 精修已完成；搜索、高亮、KaTeX 和图片查看待实现 |
| Phase 4 Agent 文档协作 | 未开始 | 已有基础监听，原子替换和阅读位置仍需强化 |
| Phase 5 质量优化 | 未开始 | 性能、长文档、频繁修改和 Release 验收待执行 |

## 已实现

- Swift Package 原生 macOS 应用骨架，最低 macOS 15。
- SwiftUI 三栏界面、原生工具栏和设置窗口。
- 文件夹懒加载和 Markdown 文件过滤。
- VS Code 式预览标签：单击预览、双击固定，并支持关闭其它与关闭右侧。
- `swift-markdown` AST 解析、HTML 转义和 WKWebView 渲染。
- AST 标题 source range 生成大纲和源码行号。
- 大纲点击跳转、正文滚动章节同步、章节位置复制。
- Mermaid 11.17.2 本地按需加载、严格安全模式、适应宽度、缩放、平移和错误降级。
- 文档内相对 Markdown 链接、中文文件名、无扩展名链接、目录 README 和章节锚点跳转。
- UI Walk 样本文档、三栏高度自适应、精简空状态和阅读排版细节。
- Everforest Light、Swiss、Ink、Manuscript 四套样式；正文保持舒适行宽，宽表格按阅读视口展开。
- Everforest Light 使用宽幅统一内容轴、奶油色背景、蓝灰正文、绿色链接和琥珀色行内代码。
- 默认回归 Marked 3 Swiss 取向；Mermaid 保持自然尺寸并左对齐，仅在超出视口时缩小。
- Marked 3 风格紧凑表格：常见五列表格列宽优化、纯色表体和专注阅读模式。
- 文件事件监听、防抖和基本自动刷新。
- 本地 `.app` 打包、ad-hoc/开发证书签名和签名校验。
- 原创 Keen 图标接入资源。

## 待验证或待完善

- [x] 完成首次 `swift build`，依赖实际解析为 `swift-markdown 0.9.0`。
- [x] 完成自动化测试并生成 `.build/app/Keen.app`。
- [ ] 用真实项目手工验证三栏布局与大纲导航。
- [x] GFM 表格和任务列表 HTML 输出。
- [ ] 代码语法高亮和语言标签。
- [x] Mermaid 按需加载、缩放和平移。
- [ ] KaTeX 数学公式。
- [ ] `⌘F` 可见文本搜索。
- [ ] 可靠处理原子替换、删除、恢复和重命名。
- [ ] 用标题锚点 + 段落标识 + 相对偏移恢复阅读位置。
- [ ] Security-Scoped Bookmark 持久化，不仅是本次进程授权。
- [ ] 文件树监听和变更更新。
- [ ] 性能与内存测试报告。

## 验证记录

- `make build`：通过。
- `make test`：7 项测试通过，0 项失败。
- `make app`：Release 构建、AppIcon 资产编译、ad-hoc 签名和签名校验通过。
- `.build/app/Keen.app`：成功启动并持续运行超过 20 秒。
- 真实项目内的视觉与交互验收尚未完成，详见 `docs/TEST_REPORT.md`。

## 图标设计记录

生成方式：Codex 内置图像生成工具。最终资源：`Resources/AppIcon.png`，构建时转换为 `AppIcon.icns`。

生成提示词摘要：为 Keen 原生 Markdown 阅读器设计 macOS 图标，以折叠文档页和负空间视线表达“专注阅读与清晰”，使用深墨蓝、暖白和少量青色，保持简单几何、轻微纸张层次、清晰轮廓；禁止文字、水印、霓虹、过度渐变和通用书本图标。

## 下一步

1. 构建并修复编译问题。
2. 运行测试和打包脚本。
3. 启动 App 做首轮真实交互验收。
4. 根据 MVP 验收结果更新本文件，再进入 Phase 3。
