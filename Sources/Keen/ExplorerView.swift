import AppKit
import SwiftUI

struct ExplorerView: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("文件")
                    .font(.headline)
                Spacer()
                Button { store.chooseFolder() } label: { Image(systemName: "folder.badge.plus") }
                    .buttonStyle(.borderless)
                    .help("打开文件夹")
            }
            .padding(12)
            Divider()

            if let root = store.rootNode {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        FileNodeRow(node: root, depth: 0, initiallyExpanded: true)
                            .environmentObject(store)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                ContentUnavailableView("未打开文件夹", systemImage: "folder", description: Text("按 ⇧⌘O 选择工作区"))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct FileNodeRow: View {
    @EnvironmentObject private var store: WorkspaceStore
    let node: FileNode
    let depth: Int
    @State private var expanded: Bool
    @State private var children: [FileNode] = []

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
        }
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
