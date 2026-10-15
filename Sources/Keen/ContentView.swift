import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var isDropTargeted = false
    @State private var findQuery = ""
    @State private var findCommand = PageFindCommand()
    @State private var findResult = PageFindResult()
    @FocusState private var findFieldFocused: Bool

    var body: some View {
        HSplitView {
            if store.showExplorer && !store.focusMode {
                ExplorerView()
                    .environmentObject(store)
                    .frame(minWidth: 190, idealWidth: 240, maxWidth: 360)
            }

            VStack(spacing: 0) {
                TabBarView()
                    .environmentObject(store)
                Divider()
                reader
            }
            .frame(minWidth: 500)

            if store.showOutline && !store.focusMode {
                OutlineView()
                    .environmentObject(store)
                    .frame(minWidth: 170, idealWidth: 260)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(store.selectedDocument?.title ?? "Keen")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { store.navigateBack() } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!store.canNavigateBack)
                .help("后退（⌘[）")

                Button { store.navigateForward() } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!store.canNavigateForward)
                .help("前进（⌘]）")

                Button { store.showExplorer.toggle() } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(store.showExplorer ? "隐藏文件侧栏" : "显示文件侧栏")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { store.chooseFile() } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .help("打开文件")
                Button { store.showOutline.toggle() } label: {
                    Image(systemName: "list.bullet.indent")
                }
                .help(store.showOutline ? "隐藏大纲" : "显示大纲")
                Button { store.focusMode.toggle() } label: {
                    Image(systemName: store.focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .help(store.focusMode ? "退出专注阅读" : "专注阅读")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let string = String(data: data, encoding: .utf8), let url = URL(string: string) else { return }
                    Task { @MainActor in store.handleDroppedURLs([url]) }
                }
            }
            return !providers.isEmpty
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .onOpenURL { url in
            if let target = DocumentLinkResolver.resolve(url) {
                store.openFile(target.fileURL, headingID: target.headingID)
            } else {
                store.openFile(url)
            }
        }
        .onChange(of: store.theme) { _, _ in store.persistPreferences() }
        .onChange(of: store.readingStyle) { _, _ in store.persistPreferences() }
        .onChange(of: store.fontSize) { _, _ in store.persistPreferences() }
        .onChange(of: store.readingWidth) { _, _ in store.persistPreferences() }
        .onChange(of: store.showExplorer) { _, _ in store.persistPreferences() }
        .onChange(of: store.showHiddenFiles) { _, _ in store.persistPreferences() }
        .onChange(of: store.showFindBar) { _, isPresented in
            if isPresented {
                findCommand.activate(query: findQuery)
                focusFindField()
            } else {
                findCommand.deactivate()
            }
        }
        .onChange(of: store.findFocusRequest) { _, _ in focusFindField() }
        .sheet(isPresented: $store.showRecentFiles) {
            RecentFilesView()
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private var reader: some View {
        if let message = store.errorMessage {
            ContentUnavailableView("无法读取文档", systemImage: "exclamationmark.triangle", description: Text(message))
        } else if let rendered = store.renderedDocument, let document = store.selectedDocument {
            VStack(spacing: 0) {
                if store.showFindBar {
                    PageFindBar(
                        query: $findQuery,
                        result: findResult,
                        isFocused: $findFieldFocused,
                        findPrevious: { requestFind(backwards: true) },
                        findNext: { requestFind(backwards: false) },
                        close: { store.showFindBar = false }
                    )
                    .onChange(of: findQuery) { _, _ in requestFind(backwards: false) }
                }
                MarkdownWebView(
                    document: rendered,
                    sourceURL: document.url,
                    baseURL: document.url.deletingLastPathComponent(),
                    theme: store.theme,
                    readingStyle: store.readingStyle,
                    fontSize: store.fontSize,
                    readingWidth: store.readingWidth,
                    reloadToken: store.reloadToken,
                    findCommand: findCommand,
                    findResult: $findResult,
                    selectedHeadingID: $store.selectedHeadingID,
                    openLocalMarkdown: { url, headingID in
                        store.openLinkedDocument(url, headingID: headingID)
                    }
                )
                Divider()
                ReaderStatusBar(document: document)
                    .environmentObject(store)
            }
        } else {
            EmptyReaderView(
                openFile: store.chooseFile,
                openFolder: store.chooseFolder
            )
        }
    }

    private func requestFind(backwards: Bool) {
        findCommand.request(query: findQuery, backwards: backwards)
    }

    private func focusFindField() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            guard store.showFindBar else { return }
            findFieldFocused = true
        }
    }
}

private struct RecentFilesView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedURL: URL?
    @FocusState private var listFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("最近打开的文件")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("最近 \(store.recentDocuments.count) 个")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)

            Divider()

            if store.recentDocuments.isEmpty {
                ContentUnavailableView("没有最近文件", systemImage: "clock")
            } else {
                List(store.recentDocuments, id: \.self, selection: $selectedURL) { url in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(url.deletingPathExtension().lastPathComponent)
                                .lineLimit(1)
                            Text(url.deletingLastPathComponent().path)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .tag(url)
                    .onTapGesture { open(url) }
                }
                .focused($listFocused)
            }

            Divider()
            HStack {
                Text("单击打开  ·  ↑↓ 选择  ·  ↩ 打开  ·  Esc 关闭")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("打开") { openSelected() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedURL == nil)
            }
            .padding(14)
        }
        .frame(width: 620, height: 430)
        .onAppear {
            selectedURL = store.recentDocuments.first
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                listFocused = true
            }
        }
    }

    private func openSelected() {
        guard let selectedURL else { return }
        open(selectedURL)
    }

    private func open(_ url: URL) {
        dismiss()
        store.openRecentFile(url)
    }
}

private struct PageFindBar: View {
    @Binding var query: String
    let result: PageFindResult
    var isFocused: FocusState<Bool>.Binding
    let findPrevious: () -> Void
    let findNext: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("在页面中查找", text: $query)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .onSubmit(findNext)
                .frame(minWidth: 180, idealWidth: 260, maxWidth: 360)

            Text(resultLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(result.count == 0 && !query.isEmpty ? .red : .secondary)
                .frame(minWidth: 48, alignment: .trailing)

            Button(action: findPrevious) { Image(systemName: "chevron.up") }
                .disabled(query.isEmpty || result.count == 0)
                .help("上一个")
            Button(action: findNext) { Image(systemName: "chevron.down") }
                .disabled(query.isEmpty || result.count == 0)
                .help("下一个（回车）")
            Button(action: close) { Image(systemName: "xmark") }
                .keyboardShortcut(.cancelAction)
                .help("关闭（Esc）")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var resultLabel: String {
        guard !query.isEmpty else { return "" }
        guard result.count > 0 else { return "无结果" }
        return "\(result.index)/\(result.count)"
    }
}

private struct ReaderStatusBar: View {
    @EnvironmentObject private var store: WorkspaceStore
    let document: OpenDocument

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(ReadingStyle.allCases) { style in
                    Button {
                        store.readingStyle = style
                    } label: {
                        if store.readingStyle == style {
                            Label(style.label, systemImage: "checkmark")
                        } else {
                            Text(style.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "textformat")
                    Text(store.readingStyle.label)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .frame(minWidth: 82, alignment: .leading)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(store.readingStyle.description)

            Divider().frame(height: 14)

            Button { store.adjustFontSize(by: -1) } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .buttonStyle(.borderless)
            .help("减小字号")

            Text("\(Int(store.fontSize))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 20)

            Button { store.adjustFontSize(by: 1) } label: {
                Image(systemName: "textformat.size.larger")
            }
            .buttonStyle(.borderless)
            .help("增大字号")

            Spacer()

            Text(document.url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(.bar)
    }
}

private struct EmptyReaderView: View {
    let openFile: () -> Void
    let openFolder: () -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor.opacity(0.09))
                        .frame(width: 68, height: 68)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.bottom, 20)

                Text("打开 Markdown 文档")
                    .font(.system(size: 22, weight: .semibold))
                Text("选择文档或项目文件夹，也可以直接从 Finder 拖入。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    Button("打开文件…", action: openFile)
                        .frame(minWidth: 92)
                    Button("打开文件夹…", action: openFolder)
                        .frame(minWidth: 106)
                }
                .controlSize(.large)
                .padding(.top, 22)

                Text("⌘O 打开文件  ·  ⇧⌘O 打开文件夹")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 14)
            }
            .padding(40)
        }
    }
}

private struct TabBarView: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        if !store.openDocuments.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(store.openDocuments) { document in
                            HStack(spacing: 6) {
                                Button { store.select(document) } label: {
                                    Text(document.title)
                                        .italic(store.isPreview(document))
                                }
                                    .buttonStyle(.plain)
                                    .lineLimit(1)
                                Button { store.close(document) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(store.selectedDocument == document ? Color.accentColor.opacity(0.13) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .id(document.id)
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded { store.pin(document) }
                            )
                            .contextMenu {
                                if store.isPreview(document) {
                                    Button("固定标签") { store.pin(document) }
                                    Divider()
                                }
                                Button("关闭") { store.close(document) }
                                Button("关闭其它") { store.closeOthers(keeping: document) }
                                    .disabled(store.openDocuments.count <= 1)
                                Button("关闭右侧") { store.closeToRight(of: document) }
                                    .disabled(!store.hasDocumentsToRight(of: document))
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
                .frame(height: 39)
                .background(.bar)
                .onAppear { revealSelection(proxy) }
                .onChange(of: store.selectedDocument?.id) { _, _ in revealSelection(proxy) }
            }
        }
    }

    private func revealSelection(_ proxy: ScrollViewProxy) {
        guard let id = store.selectedDocument?.id else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            proxy.scrollTo(id, anchor: .trailing)
        }
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        Form {
            Picker("阅读样式", selection: $store.readingStyle) {
                ForEach(ReadingStyle.allCases) { style in Text(style.label).tag(style) }
            }
            Picker("外观", selection: $store.theme) {
                ForEach(ReadingTheme.allCases) { theme in Text(theme.label).tag(theme) }
            }
            Slider(value: $store.fontSize, in: 12...24, step: 1) {
                Text("正文大小")
            } minimumValueLabel: { Text("12") } maximumValueLabel: { Text("24") }
            Slider(value: $store.readingWidth, in: 640...1200, step: 20) {
                Text("阅读宽度")
            }
            Toggle("显示隐藏文件", isOn: $store.showHiddenFiles)
        }
        .padding(20)
        .frame(width: 420)
    }
}
