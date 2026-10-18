import AppKit
import SwiftUI

@MainActor
private final class ExplorerTreeState: ObservableObject {
    @Published private(set) var expandedURLs: Set<URL> = []
    @Published var cursorURL: URL?

    func reset(rootURL: URL?) {
        expandedURLs = rootURL.map { [$0.standardizedFileURL] } ?? []
        cursorURL = rootURL?.standardizedFileURL
    }

    func isExpanded(_ url: URL) -> Bool {
        expandedURLs.contains(url.standardizedFileURL)
    }

    func expand(_ url: URL) {
        expandedURLs.insert(url.standardizedFileURL)
    }

    func collapse(_ url: URL) {
        expandedURLs.remove(url.standardizedFileURL)
    }

    func toggle(_ url: URL) {
        let normalized = url.standardizedFileURL
        if expandedURLs.contains(normalized) { expandedURLs.remove(normalized) }
        else { expandedURLs.insert(normalized) }
    }
}

struct ExplorerView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var showWorkspaceMenu = false
    @StateObject private var treeState = ExplorerTreeState()
    @FocusState private var treeFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let root = store.rootNode {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            FileNodeRow(node: root, depth: 0, treeState: treeState) {
                                treeFocused = true
                            }
                                .environmentObject(store)
                                .id(root.id)
                        }
                        .padding(.vertical, 6)
                    }
                    .onAppear { revealCurrentDocument(using: proxy) }
                    .onChange(of: store.selectedDocument?.url) { _, _ in
                        revealCurrentDocument(using: proxy)
                    }
                    .onChange(of: treeState.cursorURL) { _, url in
                        guard let url else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(url.standardizedFileURL, anchor: .center)
                        }
                    }
                }
            } else {
                ContentUnavailableView("未打开文件夹", systemImage: "folder", description: Text("按 ⇧⌘O 选择工作区"))
            }

            Divider()
            Button { showWorkspaceMenu.toggle() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "folder")
                    Text(store.rootNode?.name ?? "打开文件夹")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .popover(isPresented: $showWorkspaceMenu, arrowEdge: .bottom) {
                WorkspaceMenuView(isPresented: $showWorkspaceMenu)
                    .environmentObject(store)
            }
        }
        .background(Color(red: 0.968, green: 0.970, blue: 0.972))
        .focusable()
        .focused($treeFocused)
        .focusEffectDisabled()
        .onMoveCommand(perform: moveSelection)
        .onKeyPress(.space) {
            guard treeFocused else { return .ignored }
            activateCursor()
            return .handled
        }
        .onKeyPress("j") { vimMove(.down) }
        .onKeyPress("k") { vimMove(.up) }
        .onKeyPress("h") { vimMove(.left) }
        .onKeyPress("l") { vimMove(.right) }
        .onAppear { treeState.reset(rootURL: store.rootNode?.url) }
        .onChange(of: store.rootNode?.id) { _, _ in
            treeState.reset(rootURL: store.rootNode?.url)
        }
    }

    private func revealCurrentDocument(using proxy: ScrollViewProxy) {
        guard let url = store.selectedDocument?.url.standardizedFileURL else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(url, anchor: .center)
            }
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        let nodes = visibleNodes()
        guard !nodes.isEmpty else { return }
        let cursor = treeState.cursorURL?.standardizedFileURL
        let index = cursor.flatMap { url in nodes.firstIndex { $0.url.standardizedFileURL == url } } ?? 0

        switch direction {
        case .up:
            treeState.cursorURL = nodes[max(0, index - 1)].url.standardizedFileURL
        case .down:
            treeState.cursorURL = nodes[min(nodes.count - 1, index + 1)].url.standardizedFileURL
        case .left:
            let node = nodes[index]
            if node.isDirectory, treeState.isExpanded(node.url) {
                treeState.collapse(node.url)
            } else if let parent = parentNode(of: node, in: nodes) {
                treeState.cursorURL = parent.url.standardizedFileURL
            }
        case .right:
            let node = nodes[index]
            guard node.isDirectory else { return }
            if treeState.isExpanded(node.url) {
                if index + 1 < nodes.count, node.contains(nodes[index + 1].url) {
                    treeState.cursorURL = nodes[index + 1].url.standardizedFileURL
                }
            } else {
                treeState.expand(node.url)
            }
        default:
            break
        }
    }

    private func vimMove(_ direction: MoveCommandDirection) -> KeyPress.Result {
        guard treeFocused, store.vimNavigationEnabled else { return .ignored }
        moveSelection(direction)
        return .handled
    }

    private func activateCursor() {
        let nodes = visibleNodes()
        guard let cursor = treeState.cursorURL?.standardizedFileURL,
              let node = nodes.first(where: { $0.url.standardizedFileURL == cursor }) else { return }
        guard !node.isDirectory else { return }
        store.openFile(node.url)
    }

    private func visibleNodes() -> [FileNode] {
        guard let root = store.rootNode else { return [] }
        var result: [FileNode] = []
        appendVisible(root, to: &result)
        return result
    }

    private func appendVisible(_ node: FileNode, to result: inout [FileNode]) {
        result.append(node)
        guard node.isDirectory, treeState.isExpanded(node.url) else { return }
        for child in node.loadChildren(showHidden: store.showHiddenFiles) {
            appendVisible(child, to: &result)
        }
    }

    private func parentNode(of node: FileNode, in nodes: [FileNode]) -> FileNode? {
        let parentURL = node.url.deletingLastPathComponent().standardizedFileURL
        return nodes.first { $0.isDirectory && $0.url.standardizedFileURL == parentURL }
    }
}

private struct WorkspaceMenuView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("操作")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 11)
                .padding(.bottom, 3)

            WorkspaceActionRow(title: "打开文件夹…", systemImage: "folder.badge.plus") {
                isPresented = false
                store.chooseFolder()
            }
            WorkspaceActionRow(title: "在 Finder 中显示", systemImage: "finder") {
                isPresented = false
                store.revealWorkspaceInFinder()
            }
            .disabled(store.rootNode == nil)
            WorkspaceActionRow(title: "刷新", systemImage: "arrow.clockwise") {
                isPresented = false
                store.refreshWorkspace()
            }
            .disabled(store.rootNode == nil)

            Divider().padding(.vertical, 5)

            Text("最近使用的目录")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 3)

            if store.recentWorkspaces.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            } else {
                ForEach(store.recentWorkspaces, id: \.self) { url in
                    RecentWorkspaceRow(
                        url: url,
                        isCurrent: store.rootNode?.url.standardizedFileURL == url.standardizedFileURL,
                        isPinned: store.isWorkspacePinned(url),
                        open: {
                            isPresented = false
                            store.openFolder(url)
                        },
                        togglePinned: { store.togglePinnedWorkspace(url) },
                        remove: { store.removeRecentWorkspace(url) }
                    )
                }
            }
        }
        .padding(.bottom, 6)
        .frame(width: 292)
    }
}

private struct WorkspaceActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .contentShape(Rectangle())
                .background(isHovered ? Color.primary.opacity(0.055) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct RecentWorkspaceRow: View {
    let url: URL
    let isCurrent: Bool
    let isPinned: Bool
    let open: () -> Void
    let togglePinned: () -> Void
    let remove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: open) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(url.lastPathComponent)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(url.path)

            if isHovered || isPinned {
                Button(action: togglePinned) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundStyle(isPinned ? Color.accentColor : .secondary)
                .help(isPinned ? "取消固定" : "固定")

                Button(action: remove) {
                    Image(systemName: "trash")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundStyle(.secondary)
                .help("从最近目录移除")
            } else if isCurrent {
                Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                    .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 31)
        .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

private struct FileNodeRow: View {
    @EnvironmentObject private var store: WorkspaceStore
    @ObservedObject var treeState: ExplorerTreeState
    let node: FileNode
    let depth: Int
    let focusTree: () -> Void
    @State private var children: [FileNode] = []
    @State private var watcher: FileWatcher?

    init(
        node: FileNode,
        depth: Int,
        treeState: ExplorerTreeState,
        focusTree: @escaping () -> Void = {}
    ) {
        self.node = node
        self.depth = depth
        self.treeState = treeState
        self.focusTree = focusTree
    }

    private var expanded: Bool { treeState.isExpanded(node.url) }
    private var hasCursor: Bool { treeState.cursorURL?.standardizedFileURL == node.url.standardizedFileURL }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                if node.isDirectory {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 12)
                    Image(systemName: expanded ? "folder.fill" : "folder")
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear.frame(width: 12, height: 1)
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                }
                Text(node.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(node.isDirectory ? Color.primary.opacity(0.67) : Color.primary.opacity(0.76))
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(depth) * 13 + 8)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(rowBackground)
            .id(node.url.standardizedFileURL)
            .gesture(rowGesture)
            .contextMenu {
                Button("打开") {
                    if node.isDirectory { store.openFolder(node.url) } else { store.openFile(node.url) }
                }
                if !node.isDirectory {
                    Button("固定打开") { store.openFile(node.url, pinned: true) }
                }
                Button("复制绝对路径") { copy(node.url.path) }
                if let root = store.rootNode?.url,
                   let relative = node.url.path.removingPrefix(root.path + "/") {
                    Button("复制相对路径") { copy(relative) }
                }
                Divider()
                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
            }

            if node.isDirectory && expanded {
                ForEach(children) { child in
                    FileNodeRow(node: child, depth: depth + 1, treeState: treeState, focusTree: focusTree)
                        .environmentObject(store)
                }
            }
        }
        .onAppear {
            revealSelectedDocument()
            if expanded { children = node.loadChildren(showHidden: store.showHiddenFiles) }
            watchDirectory()
        }
        .onChange(of: store.selectedDocument?.url) { _, _ in revealSelectedDocument() }
        .onChange(of: expanded) { _, isExpanded in
            if isExpanded { children = node.loadChildren(showHidden: store.showHiddenFiles) }
        }
        .onChange(of: store.showHiddenFiles) { _, _ in reloadDirectory() }
        .onDisappear { watcher = nil }
    }

    private var rowGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { value in
                focusTree()
                treeState.cursorURL = node.url.standardizedFileURL
                switch value {
                case .first:
                    if node.isDirectory {
                        toggleDirectory()
                    } else {
                        store.openFile(node.url, pinned: true)
                    }
                case .second:
                    if node.isDirectory { toggleDirectory() }
                    else { store.openFile(node.url) }
                }
            }
    }

    private func toggleDirectory() {
        treeState.toggle(node.url)
        if expanded { children = node.loadChildren(showHidden: store.showHiddenFiles) }
    }

    private func revealSelectedDocument() {
        guard node.isDirectory,
              let selectedURL = store.selectedDocument?.url,
              node.contains(selectedURL) else { return }
        treeState.expand(node.url)
        children = node.loadChildren(showHidden: store.showHiddenFiles)
    }

    private var rowBackground: Color {
        if hasCursor { return Color.black.opacity(0.10) }
        if store.selectedDocument?.url.standardizedFileURL == node.url.standardizedFileURL {
            return Color.black.opacity(0.055)
        }
        return .clear
    }

    private func watchDirectory() {
        guard node.isDirectory else { return }
        watcher = FileWatcher(url: node.url) {
            Task { @MainActor in reloadDirectory() }
        }
    }

    private func reloadDirectory() {
        guard node.isDirectory else { return }
        children = node.reloadChildren(showHidden: store.showHiddenFiles)
        store.reconcileOpenDocuments()
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private extension String {
    func removingPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}
