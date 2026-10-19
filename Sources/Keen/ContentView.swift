import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var isDropTargeted = false
    @State private var findQuery = ""
    @State private var findCommand = PageFindCommand()
    @State private var findResult = PageFindResult()
    @State private var explorerWidth = UserDefaults.standard.object(forKey: "explorerSidebarWidth") as? Double ?? 240
    @State private var outlineWidth = UserDefaults.standard.object(forKey: "outlineSidebarWidth") as? Double ?? 180
    @State private var explorerDragStart: CGFloat?
    @State private var outlineDragStart: CGFloat?
    @State private var isFullScreen = false
    @FocusState private var findFieldFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let widths = sidebarWidths(in: geometry.size.width)
            HStack(spacing: 0) {
                if store.showExplorer && !store.focusMode {
                    ExplorerView()
                        .environmentObject(store)
                        .frame(width: widths.explorer)
                        .padding(.top, isFullScreen ? 0 : 36)
                        .background(Color(red: 0.968, green: 0.970, blue: 0.972))
                    splitDivider {
                        startExplorerResize($0, from: widths.explorer, available: geometry.size.width - widths.outline - 400 - widths.dividers)
                    } onEnd: {
                        explorerDragStart = nil
                        UserDefaults.standard.set(explorerWidth, forKey: "explorerSidebarWidth")
                    }
                }

                VStack(spacing: 0) {
                    if !isFullScreen {
                        TabBarView()
                            .environmentObject(store)
                    }
                    reader
                }
                .frame(minWidth: 400, maxWidth: .infinity)

                if store.showOutline && !store.focusMode {
                    splitDivider {
                        startOutlineResize($0, from: widths.outline, available: geometry.size.width - widths.explorer - 400 - widths.dividers)
                    } onEnd: {
                        outlineDragStart = nil
                        UserDefaults.standard.set(outlineWidth, forKey: "outlineSidebarWidth")
                    }
                    VStack(spacing: 0) {
                        if !isFullScreen {
                            HeaderControls()
                                .environmentObject(store)
                        }
                        OutlineView()
                            .environmentObject(store)
                    }
                    .frame(width: widths.outline)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .top)
        .background(WindowAppearance(isFullScreen: $isFullScreen, store: store))
        .navigationTitle(store.selectedDocument?.title ?? "Keen")
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { notification in
            guard let window = notification.object as? NSWindow, window == NSApp.keyWindow else { return }
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
            guard let window = notification.object as? NSWindow, window == NSApp.keyWindow else { return }
            isFullScreen = false
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
        .onChange(of: store.fontSize) { _, _ in store.persistPreferences() }
        .onChange(of: store.readingWidth) { _, _ in store.persistPreferences() }
        .onChange(of: store.showExplorer) { _, _ in store.persistPreferences() }
        .onChange(of: store.showOutline) { _, _ in store.persistPreferences() }
        .onChange(of: store.vimNavigationEnabled) { _, _ in store.persistPreferences() }
        .onChange(of: store.showHiddenFiles) { _, _ in store.persistPreferences() }
        .onChange(of: store.workspaceFindRequest) { _, _ in
            findQuery = store.workspaceFindQuery
            store.showFindBar = true
            findCommand.activate(query: findQuery)
        }
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

    private func splitDivider(
        onDrag: @escaping (CGFloat) -> Void,
        onEnd: @escaping () -> Void
    ) -> some View {
        Color.clear
            .frame(width: 8)
            .overlay {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.set() }
                else { NSCursor.arrow.set() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { onDrag($0.translation.width) }
                    .onEnded { _ in onEnd() }
            )
    }

    private func sidebarWidths(in totalWidth: CGFloat) -> (explorer: CGFloat, outline: CGFloat, dividers: CGFloat) {
        let hasExplorer = store.showExplorer && !store.focusMode
        let hasOutline = store.showOutline && !store.focusMode
        let dividers = CGFloat((hasExplorer ? 1 : 0) + (hasOutline ? 1 : 0)) * 8
        var explorer = hasExplorer ? max(180, CGFloat(explorerWidth)) : 0
        var outline = hasOutline ? max(140, CGFloat(outlineWidth)) : 0
        let excess = max(0, explorer + outline + dividers + 400 - totalWidth)
        let explorerFlex = hasExplorer ? explorer - 180 : 0
        let outlineFlex = hasOutline ? outline - 140 : 0
        let flex = explorerFlex + outlineFlex
        if flex > 0 {
            explorer -= min(excess, flex) * explorerFlex / flex
            outline -= min(excess, flex) * outlineFlex / flex
        }
        return (explorer, outline, dividers)
    }

    private func startExplorerResize(_ translation: CGFloat, from currentWidth: CGFloat, available: CGFloat) {
        if explorerDragStart == nil { explorerDragStart = currentWidth }
        explorerWidth = Double(min(max(180, available), max(180, (explorerDragStart ?? currentWidth) + translation)))
    }

    private func startOutlineResize(_ translation: CGFloat, from currentWidth: CGFloat, available: CGFloat) {
        if outlineDragStart == nil { outlineDragStart = currentWidth }
        outlineWidth = Double(min(max(140, available), max(140, (outlineDragStart ?? currentWidth) - translation)))
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
                    },
                    onVimCommand: { command in
                        switch command {
                        case .nextFind:
                            requestVimFind(backwards: false)
                        case .previousFind:
                            requestVimFind(backwards: true)
                        case .back:
                            store.navigateBack()
                        case .forward:
                            store.navigateForward()
                        case .nextTab:
                            store.selectAdjacentTab(1)
                        case .previousTab:
                            store.selectAdjacentTab(-1)
                        }
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

    private func requestVimFind(backwards: Bool) {
        guard !findQuery.isEmpty else { return }
        if !findCommand.active { findCommand.activate(query: findQuery) }
        requestFind(backwards: backwards)
    }

    private func focusFindField() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            guard store.showFindBar else { return }
            findFieldFocused = true
        }
    }
}

private struct WindowAppearance: NSViewRepresentable {
    @Binding var isFullScreen: Bool
    let store: WorkspaceStore

    final class Coordinator {
        var accessory: NSTitlebarAccessoryViewController?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window, coordinator: context.coordinator) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(view.window, coordinator: context.coordinator) }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        guard let window = view.window,
              let accessory = coordinator.accessory,
              let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) else { return }
        window.removeTitlebarAccessoryViewController(at: index)
        coordinator.accessory = nil
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .white
        let actualFullScreen = window.styleMask.contains(.fullScreen)
        if isFullScreen != actualFullScreen {
            isFullScreen = actualFullScreen
        }
        if actualFullScreen && coordinator.accessory == nil {
            let accessory = NSTitlebarAccessoryViewController()
            accessory.layoutAttribute = .right
            let controls = NSHostingView(rootView: HeaderControlsButtons().environmentObject(store))
            controls.frame = NSRect(x: 0, y: 0, width: 72, height: 36)
            accessory.view = controls
            window.addTitlebarAccessoryViewController(accessory)
            coordinator.accessory = accessory
        } else if !actualFullScreen, let accessory = coordinator.accessory {
            if let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            coordinator.accessory = nil
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
    @State private var results: [WorkspaceSearchHit] = []
    @State private var selectedURL: URL?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var workerTask: Task<[WorkspaceSearchHit], Never>?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Text("搜索工作区内容")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text(isSearching ? "搜索中…" : "\(results.count) 个结果")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索 Markdown 正文，也可输入相对路径", text: $query)
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

            if isSearching {
                ProgressView("正在搜索工作区…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(results, id: \.url, selection: $selectedURL) { hit in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hit.url.deletingPathExtension().lastPathComponent)
                                .lineLimit(1)
                            Text(hit.relativePath)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let excerpt = hit.excerpt, let line = hit.lineNumber {
                                Text("第 \(line) 行 · \(excerpt)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .tag(hit.url)
                    .onTapGesture {
                        selectedURL = hit.url
                        Task { @MainActor in
                            await Task.yield()
                            open(hit)
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()
            HStack {
                Text("搜索正文与相对路径  ·  ↑↓ 选择  ·  ↩ 打开")
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
        .onDisappear {
            searchTask?.cancel()
            workerTask?.cancel()
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        workerTask?.cancel()
        guard let rootURL = store.rootNode?.url else { return }
        isSearching = true
        results = []
        selectedURL = nil
        let needle = query
        let showHidden = store.showHiddenFiles
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(needle.isEmpty ? 0 : 180))
            guard !Task.isCancelled else { return }
            let worker = Task.detached(priority: .userInitiated) {
                WorkspaceTextSearch.search(rootURL: rootURL, query: needle, showHidden: showHidden)
            }
            workerTask = worker
            let found = await worker.value
            guard !Task.isCancelled, !worker.isCancelled else { return }
            results = found
            selectedURL = found.first?.url
            isSearching = false
        }
    }

    private func openSelected() {
        guard let selectedURL, let hit = results.first(where: { $0.url == selectedURL }) else { return }
        open(hit)
    }

    private func open(_ hit: WorkspaceSearchHit) {
        dismiss()
        store.openFile(hit.url)
        if hit.lineNumber != nil {
            store.workspaceFindQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            store.workspaceFindRequest = UUID()
        }
    }

    private func moveSelection(by offset: Int) {
        guard !results.isEmpty else { selectedURL = nil; return }
        let current = selectedURL.flatMap { url in results.firstIndex(where: { $0.url == url }) } ?? (offset > 0 ? -1 : 0)
        selectedURL = results[(current + offset + results.count) % results.count].url
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

private struct TabBarView: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(store.openDocuments) { document in
                            HStack(spacing: 6) {
                                Button { store.select(document) } label: {
                                    Text(document.title)
                                        .italic(store.isPreview(document))
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                                .focusEffectDisabled()

                                Button { store.close(document) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .focusEffectDisabled()
                                .help("关闭文件")
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 27)
                            .background(store.selectedDocument == document ? Color.accentColor.opacity(0.13) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contextMenu {
                                if store.isPreview(document) {
                                    Button("固定标签") { store.pin(document) }
                                }
                                Button("关闭") { store.close(document) }
                                Button("关闭其它") { store.closeOthers(keeping: document) }
                                    .disabled(store.openDocuments.count <= 1)
                                Button("关闭右侧") { store.closeToRight(of: document) }
                                    .disabled(!store.hasDocumentsToRight(of: document))
                            }
                            .id(document.id)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                Spacer(minLength: 0)
                    .contentShape(Rectangle())
                    .gesture(WindowDragGesture())
                if !store.showOutline || store.focusMode {
                    HeaderControlsButtons()
                        .environmentObject(store)
                }
            }
            .frame(height: 36)
            .background(Color(nsColor: .controlBackgroundColor))
            .onAppear { revealSelection(proxy) }
            .onChange(of: store.selectedDocument?.id) { _, _ in revealSelection(proxy) }
        }
    }

    private func revealSelection(_ proxy: ScrollViewProxy) {
        guard let id = store.selectedDocument?.id else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            proxy.scrollTo(id, anchor: .trailing)
        }
    }
}

private struct HeaderControls: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            HeaderControlsButtons()
                .environmentObject(store)
        }
        .frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct HeaderControlsButtons: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        HStack(spacing: 4) {
            button("sidebar.left", help: store.showExplorer && !store.focusMode ? "隐藏文件侧栏（⌘B）" : "显示文件侧栏（⌘B）") {
                if store.focusMode {
                    store.focusMode = false
                    store.showExplorer = true
                } else {
                    store.showExplorer.toggle()
                }
            }
            button("list.bullet", help: store.showOutline && !store.focusMode ? "隐藏大纲（⌘L）" : "显示大纲（⌘L）") {
                if store.focusMode {
                    store.focusMode = false
                    store.showOutline = true
                } else {
                    store.showOutline.toggle()
                }
            }
        }
        .padding(.trailing, 8)
    }

    private func button(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
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
