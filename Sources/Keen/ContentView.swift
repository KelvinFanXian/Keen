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

            reader
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
            ToolbarItem(placement: .primaryAction) {
                Button { store.chooseFile() } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .help("打开文件（⌘O）")
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
        .onChange(of: store.showOutline) { _, _ in store.persistPreferences() }
        .onChange(of: store.vimNavigationEnabled) { _, _ in store.persistPreferences() }
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
        .sheet(isPresented: $store.showWorkspaceSearch) {
            WorkspaceFileSearchView()
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private var reader: some View {
        if let message = store.errorMessage {
            ContentUnavailableView("无法读取文档", systemImage: "exclamationmark.triangle", description: Text(message))
        } else if let rendered = store.renderedDocument,
                  let document = store.selectedDocument,
                  store.renderedDocumentURL == document.url.standardizedFileURL {
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
                    vimNavigationEnabled: store.vimNavigationEnabled,
                    reloadToken: store.reloadToken,
                    restoreScrollY: store.requestedScrollY,
                    findCommand: findCommand,
                    findResult: $findResult,
                    selectedHeadingID: $store.selectedHeadingID,
                    openLocalMarkdown: { url, headingID in
                        store.openLinkedDocument(url, headingID: headingID)
                    },
                    onScrollPositionChanged: { url, scrollY in
                        store.updateScrollPosition(scrollY, for: url)
                    },
                    onFindRequested: {
                        store.presentFindBar()
                    }
                )
            }
        } else if let document = store.selectedDocument {
            DocumentLoadingView(title: document.title)
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

private struct DocumentLoadingView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .lineLimit(1)
            ForEach([0.92, 0.76, 0.84, 0.58], id: \.self) { width in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(maxWidth: 760 * width)
                    .frame(height: 14)
            }
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
                .frame(maxWidth: 760, minHeight: 150)
            Spacer()
        }
        .padding(.horizontal, 48)
        .padding(.top, 42)
        .frame(maxWidth: 860, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }
}

private struct RecentFilesView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedURL: URL?
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Text("最近打开的文件")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text("\(filteredDocuments.count)/\(store.recentDocuments.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("按文件名或相对路径过滤", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onSubmit(openSelected)
                        .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
                        .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
                }
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(16)

            Divider()

            if filteredDocuments.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(filteredDocuments, id: \.self, selection: $selectedURL) { url in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(url.deletingPathExtension().lastPathComponent)
                                .lineLimit(1)
                            Text(relativeDirectory(for: url))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .tag(url)
                    .onTapGesture {
                        selectedURL = url
                        Task { @MainActor in
                            await Task.yield()
                            open(url)
                        }
                    }
                }
                .listStyle(.plain)
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
            selectedURL = filteredDocuments.first
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                searchFocused = true
            }
        }
        .onChange(of: query) { _, _ in selectedURL = filteredDocuments.first }
    }

    private func openSelected() {
        guard let selectedURL else { return }
        open(selectedURL)
    }

    private func open(_ url: URL) {
        dismiss()
        store.openRecentFile(url)
    }

    private func moveSelection(by offset: Int) {
        let documents = filteredDocuments
        guard !documents.isEmpty else { selectedURL = nil; return }
        let current = selectedURL.flatMap { documents.firstIndex(of: $0) } ?? (offset > 0 ? -1 : 0)
        selectedURL = documents[(current + offset + documents.count) % documents.count]
    }

    private var filteredDocuments: [URL] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return store.recentDocuments }
        return store.recentDocuments.filter { url in
            relativePath(for: url).localizedCaseInsensitiveContains(needle)
        }
    }

    private func relativePath(for url: URL) -> String {
        guard let root = store.rootNode?.url.standardizedFileURL else { return url.path }
        return url.standardizedFileURL.path.replacingOccurrences(of: root.path + "/", with: "")
    }

    private func relativeDirectory(for url: URL) -> String {
        let path = relativePath(for: url)
        let directory = (path as NSString).deletingLastPathComponent
        return directory.isEmpty ? "." : directory
    }
}

private struct WorkspaceFileSearchView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var indexedURLs: [URL] = []
    @State private var results: [URL] = []
    @State private var selectedURL: URL?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Text("搜索工作区文件")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text("\(results.count) 个结果")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("输入文件名或相对路径", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onSubmit(openSelected)
                        .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
                        .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
                }
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(16)

            Divider()

            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(results, id: \.self, selection: $selectedURL) { url in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(url.deletingPathExtension().lastPathComponent)
                                .lineLimit(1)
                            Text(relativeDirectory(for: url))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .tag(url)
                    .onTapGesture {
                        selectedURL = url
                        Task { @MainActor in
                            await Task.yield()
                            open(url)
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()
            HStack {
                Text("按文件名或相对路径匹配  ·  ↑↓ 选择  ·  ↩ 打开")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("打开") { openSelected() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedURL == nil)
            }
            .padding(14)
        }
        .frame(width: 660, height: 500)
        .onAppear {
            scheduleSearch()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                searchFocused = true
            }
        }
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onDisappear { searchTask?.cancel() }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(indexedURLs.isEmpty ? 0 : 45))
            guard !Task.isCancelled, let root = store.rootNode else { return }
            if indexedURLs.isEmpty {
                let rootURL = root.url
                let showHidden = store.showHiddenFiles
                indexedURLs = await Task.detached(priority: .userInitiated) {
                    FileNode.searchMarkdownFileURLs(
                        rootURL: rootURL,
                        matching: "",
                        showHidden: showHidden,
                        limit: 5_000
                    )
                }.value
            }
            guard !Task.isCancelled else { return }
            let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
            results = indexedURLs.filter {
                needle.isEmpty || relativePath(for: $0).localizedCaseInsensitiveContains(needle)
            }.prefix(200).map { $0 }
            selectedURL = results.first
        }
    }

    private func openSelected() {
        guard let selectedURL else { return }
        open(selectedURL)
    }

    private func open(_ url: URL) {
        dismiss()
        store.openFile(url)
    }

    private func moveSelection(by offset: Int) {
        guard !results.isEmpty else { selectedURL = nil; return }
        let current = selectedURL.flatMap { results.firstIndex(of: $0) } ?? (offset > 0 ? -1 : 0)
        selectedURL = results[(current + offset + results.count) % results.count]
    }

    private func relativePath(for url: URL) -> String {
        guard let root = store.rootNode?.url.standardizedFileURL else { return url.path }
        return url.standardizedFileURL.path.replacingOccurrences(of: root.path + "/", with: "")
    }

    private func relativeDirectory(for url: URL) -> String {
        let relative = relativePath(for: url)
        let directory = (relative as NSString).deletingLastPathComponent
        return directory.isEmpty ? "." : directory
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
            Toggle("启用 Vim 风格阅读导航（只读）", isOn: $store.vimNavigationEnabled)
        }
        .padding(20)
        .frame(width: 420)
    }
}
