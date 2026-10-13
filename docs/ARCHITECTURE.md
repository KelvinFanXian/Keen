# Keen 架构说明

> 维护人：范显  
> 最后更新：2026-10-13

## 一页结论

Keen 使用 SwiftUI 构建窗口与三栏布局，AppKit 提供文件面板、剪贴板和 Finder 集成，Apple `swift-markdown` 生成 AST，受控的 `WKWebView` 负责高质量只读排版。应用只保留一个当前阅读 WebView，不为每个标签长期持有独立实例。

## 模块

```text
KeenApp
└── WorkspaceStore
    ├── ExplorerView / FileNode
    ├── TabBarView
    ├── MarkdownRenderer
    │   └── swift-markdown AST → 安全 HTML
    ├── MarkdownWebView
    │   └── HTML/CSS + 章节观察桥接
    ├── OutlineView
    └── FileWatcher
```

## 数据流

1. 文件选择器、文件树、拖放或 Finder Open With 提供 URL。
2. `WorkspaceStore` 读取 UTF-8 源文档并交给 `MarkdownRenderer`。
3. Renderer 从 AST 生成正文 HTML、标题锚点和源码行号。
4. `MarkdownWebView` 以文档目录为基准加载 HTML，解析相对图片。
5. JavaScript 只负责阅读视图内部行为：章节观察、平滑跳转、排版配置和复制代码。
6. `WKScriptMessageHandler` 将当前章节回传给 SwiftUI 大纲。
7. `FileWatcher` 接收文件与已显示目录的文件系统事件，防抖后触发重新读取、目录缓存失效和渲染；删除当前文件时同步关闭失效标签。

## 安全边界

- 原始 Markdown HTML 节点统一转义，不直接注入 DOM。
- 远程图片和越过文档目录的图片路径不渲染，避免非预期网络请求与路径穿越。
- 链接点击由 `WKNavigationDelegate` 接管；仅 Markdown 本地链接在 Keen 打开，HTTP(S)/mailto 交给系统。
- WebKit 使用非持久化数据存储。
- 当前内置 JavaScript 是应用可信资源；文档不能注入脚本。
- Mermaid 11.17.2 随 App 本地打包，仅在文档包含 `mermaid` 代码块时读入页面，并固定使用 `securityLevel: strict`。

## 当前技术债务

- Security-Scoped Bookmark 尚未持久化。
- 文件原子替换后的监听重建仍需压力测试。
- 阅读位置恢复目前以章节为主，段落标识与相对偏移算法未完成。
- 语法高亮和 KaTeX 尚未接入本地资源。
