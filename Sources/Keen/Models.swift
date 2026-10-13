import Foundation

struct HeadingItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let level: Int
    let line: Int
}

struct RenderedDocument: Sendable {
    let html: String
    let headings: [HeadingItem]
}

struct OpenDocument: Identifiable, Hashable {
    let id: URL
    let url: URL
    var title: String { url.deletingPathExtension().lastPathComponent }
}

final class FileNode: Identifiable, Hashable {
    let id: URL
    let url: URL
    let isDirectory: Bool
    private(set) var children: [FileNode]?

    init(url: URL, isDirectory: Bool) {
        self.id = url
        self.url = url
        self.isDirectory = isDirectory
    }

    var name: String { url.lastPathComponent }

    func loadChildren(showHidden: Bool) -> [FileNode] {
        guard isDirectory else { return [] }
        if let children { return children }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        )) ?? []

        let loaded = urls.compactMap { child -> FileNode? in
            let values = try? child.resourceValues(forKeys: keys)
            if !showHidden && (values?.isHidden == true || child.lastPathComponent.hasPrefix(".")) {
                return nil
            }
            let directory = values?.isDirectory == true
            guard directory || ["md", "markdown"].contains(child.pathExtension.lowercased()) else {
                return nil
            }
            return FileNode(url: child, isDirectory: directory)
        }.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        children = loaded
        return loaded
    }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum ReadingTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}
