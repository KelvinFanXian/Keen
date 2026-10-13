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

    func reloadChildren(showHidden: Bool) -> [FileNode] {
        children = nil
        return loadChildren(showHidden: showHidden)
    }

    func searchMarkdownFiles(matching query: String, showHidden: Bool) -> [FileNode] {
        guard isDirectory else { return [] }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
        let options: FileManager.DirectoryEnumerationOptions = showHidden
            ? [.skipsPackageDescendants]
            : [.skipsPackageDescendants, .skipsHiddenFiles]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        ) else { return [] }

        var matches: [FileNode] = []
        for case let child as URL in enumerator {
            let values = try? child.resourceValues(forKeys: Set(keys))
            if !showHidden && (values?.isHidden == true || child.lastPathComponent.hasPrefix(".")) { continue }
            guard values?.isRegularFile == true,
                  ["md", "markdown"].contains(child.pathExtension.lowercased()),
                  child.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveContains(needle)
            else { continue }
            matches.append(FileNode(url: child, isDirectory: false))
            if matches.count == 200 { break }
        }
        return matches.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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

enum ReadingStyle: String, CaseIterable, Identifiable {
    case everforestLight = "everforest-light"
    case swiss, ink, manuscript

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everforestLight: "Everforest Light"
        case .swiss: "Swiss"
        case .ink: "Ink"
        case .manuscript: "Manuscript"
        }
    }

    var description: String {
        switch self {
        case .everforestLight: "温暖、低对比度的宽幅技术文档排版"
        case .swiss: "清晰、克制的现代排版"
        case .ink: "更紧凑的技术文档排版"
        case .manuscript: "适合长文阅读的衬线排版"
        }
    }
}
