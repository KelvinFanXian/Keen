import AppKit
import SwiftUI

struct ExplorerView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var searchText = ""
    @State private var searchResults: [FileNode] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索文件", text: $searchText)
                    .textFieldStyle(.plain)
                Button { store.chooseFolder() } label: { Image(systemName: "folder.badge.plus") }
                    .buttonStyle(.borderless)
                    .help("打开文件夹")
            }
            .padding(.horizontal, 10)
            .frame(height: 39)
            Divider()

            if let root = store.rootNode {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            FileNodeRow(node: root, depth: 0, initiallyExpanded: true)
                                .environmentObject(store)
                        } else if searchResults.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                                .padding(.top, 24)
                        } else {
                            ForEach(searchResults) { result in
                                FileNodeRow(node: result, depth: 0)
                                    .environmentObject(store)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            } else {
                ContentUnavailableView("未打开文件夹", systemImage: "folder", description: Text("按 ⇧⌘O 选择工作区"))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: searchText) { _, query in scheduleSearch(query) }
        .onChange(of: store.showHiddenFiles) { _, _ in scheduleSearch(searchText) }
        .onChange(of: store.rootNode?.id) { _, _ in scheduleSearch(searchText) }
        .onDisappear { searchTask?.cancel() }
    }

    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let root = store.rootNode else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            searchResults = root.searchMarkdownFiles(matching: trimmed, showHidden: store.showHiddenFiles)
        }
    }
}

private struct FileNodeRow: View {
    @EnvironmentObject private var store: WorkspaceStore
    let node: FileNode
    let depth: Int
    @State private var expanded: Bool
    @State private var children: [FileNode] = []
    @State private var watcher: FileWatcher?

    init(node: FileNode, depth: Int, initiallyExpanded: Bool = false) {
        self.node = node
        self.depth = depth
        _expanded = State(initialValue: initiallyExpanded)
    }

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
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(depth) * 13 + 8)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(store.selectedDocument?.url == node.url ? Color.accentColor.opacity(0.15) : Color.clear)
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
                    FileNodeRow(node: child, depth: depth + 1)
                        .environmentObject(store)
                }
            }
        }
        .onAppear {
            if expanded { children = node.loadChildren(showHidden: store.showHiddenFiles) }
            watchDirectory()
        }
        .onChange(of: store.showHiddenFiles) { _, _ in reloadDirectory() }
        .onDisappear { watcher = nil }
    }

    private var rowGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { value in
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
        expanded.toggle()
        if expanded { children = node.loadChildren(showHidden: store.showHiddenFiles) }
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
