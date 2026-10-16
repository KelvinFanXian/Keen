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

struct NavigationLocation: Hashable {
    let url: URL
    let headingID: String?
    var scrollY: Double = 0
}

struct NavigationHistory {
    private(set) var backStack: [NavigationLocation] = []
    private(set) var forwardStack: [NavigationLocation] = []

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    mutating func recordVisit(from current: NavigationLocation) {
        if backStack.last != current { backStack.append(current) }
        if backStack.count > 100 { backStack.removeFirst(backStack.count - 100) }
        forwardStack.removeAll()
    }

    mutating func goBack(from current: NavigationLocation) -> NavigationLocation? {
        guard let target = backStack.popLast() else { return nil }
        forwardStack.append(current)
        return target
    }

    mutating func goForward(from current: NavigationLocation) -> NavigationLocation? {
        guard let target = forwardStack.popLast() else { return nil }
        backStack.append(current)
        return target
    }
}

struct RecentDocumentHistory {
    let limit: Int
    private(set) var urls: [URL]

    init(urls: [URL] = [], limit: Int = 10) {
        self.limit = limit
        var seen = Set<URL>()
        self.urls = urls.map(\.standardizedFileURL).filter { seen.insert($0).inserted }.prefix(limit).map { $0 }
    }

    mutating func record(_ url: URL) {
        let normalized = url.standardizedFileURL
        urls.removeAll { $0 == normalized }
        urls.insert(normalized, at: 0)
        if urls.count > limit { urls.removeLast(urls.count - limit) }
    }

    mutating func retain(where shouldKeep: (URL) -> Bool) {
        urls.removeAll { !shouldKeep($0) }
    }
}

struct WorkspaceRecentDocumentHistory {
    private let limit: Int
    private var histories: [String: RecentDocumentHistory]

    init(pathsByWorkspace: [String: [String]] = [:], limit: Int = 10) {
        self.limit = limit
        histories = pathsByWorkspace.reduce(into: [:]) { result, entry in
            result[URL(fileURLWithPath: entry.key).standardizedFileURL.path] = RecentDocumentHistory(
                urls: entry.value.map(URL.init(fileURLWithPath:)),
                limit: limit
            )
        }
    }

    func documents(in workspaceURL: URL) -> [URL] {
        histories[workspaceKey(workspaceURL)]?.urls ?? []
    }

    mutating func record(_ documentURL: URL, in workspaceURL: URL) {
        let key = workspaceKey(workspaceURL)
        var history = histories[key] ?? RecentDocumentHistory(limit: limit)
        history.record(documentURL)
        histories[key] = history
    }

    mutating func retain(in workspaceURL: URL, where shouldKeep: (URL) -> Bool) {
        let key = workspaceKey(workspaceURL)
        guard var history = histories[key] else { return }
        history.retain(where: shouldKeep)
        histories[key] = history
    }

    var pathsByWorkspace: [String: [String]] {
        histories.mapValues { $0.urls.map(\.path) }
    }

    private func workspaceKey(_ url: URL) -> String {
        url.standardizedFileURL.path
    }
}

struct WorkspaceTabSession: Codable, Equatable {
    var openTabPaths: [String]
    var selectedPath: String?
}

struct RecentWorkspaceHistory {
    let limit: Int
    private(set) var urls: [URL]
    private(set) var pinnedURLs: Set<URL>

    init(urls: [URL] = [], pinnedURLs: [URL] = [], limit: Int = 10) {
        self.limit = limit
        var seen = Set<URL>()
        self.urls = urls.map(\.standardizedFileURL).filter { seen.insert($0).inserted }.prefix(limit).map { $0 }
        self.pinnedURLs = Set(pinnedURLs.map(\.standardizedFileURL))
        normalize()
    }

    mutating func record(_ url: URL) {
        let normalized = url.standardizedFileURL
        urls.removeAll { $0 == normalized }
        if pinnedURLs.contains(normalized) {
            urls.insert(normalized, at: 0)
        } else {
            let insertionIndex = urls.prefix { pinnedURLs.contains($0) }.count
            urls.insert(normalized, at: insertionIndex)
        }
        normalize()
    }

    mutating func togglePinned(_ url: URL) {
        let normalized = url.standardizedFileURL
        if pinnedURLs.contains(normalized) {
            pinnedURLs.remove(normalized)
        } else {
            pinnedURLs.insert(normalized)
            if !urls.contains(normalized) { urls.append(normalized) }
        }
        normalize()
    }

    mutating func remove(_ url: URL) {
        let normalized = url.standardizedFileURL
        urls.removeAll { $0 == normalized }
        pinnedURLs.remove(normalized)
    }

    func isPinned(_ url: URL) -> Bool {
        pinnedURLs.contains(url.standardizedFileURL)
    }

    mutating func retain(where shouldKeep: (URL) -> Bool) {
        urls.removeAll { !shouldKeep($0) }
        pinnedURLs = pinnedURLs.filter(shouldKeep)
    }

    private mutating func normalize() {
        let pinned = urls.filter { pinnedURLs.contains($0) }
        var unpinned = urls.filter { !pinnedURLs.contains($0) }
        let unpinnedLimit = max(0, limit - pinned.count)
        if unpinned.count > unpinnedLimit { unpinned.removeLast(unpinned.count - unpinnedLimit) }
        urls = pinned + unpinned
    }
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

    func contains(_ candidateURL: URL) -> Bool {
        guard isDirectory else { return false }
        let directoryPath = url.standardizedFileURL.path
        let candidatePath = candidateURL.standardizedFileURL.path
        return candidatePath.hasPrefix(directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/")
    }

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
        Self.searchMarkdownFileURLs(
            rootURL: url,
            matching: query,
            showHidden: showHidden
        ).map { FileNode(url: $0, isDirectory: false) }
    }

    static func searchMarkdownFileURLs(
        rootURL: URL,
        matching query: String,
        showHidden: Bool,
        limit: Int = 200
    ) -> [URL] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
        let options: FileManager.DirectoryEnumerationOptions = showHidden
            ? [.skipsPackageDescendants]
            : [.skipsPackageDescendants, .skipsHiddenFiles]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: options
        ) else { return [] }

        var matches: [URL] = []
        for case let child as URL in enumerator {
            let values = try? child.resourceValues(forKeys: Set(keys))
            if !showHidden && (values?.isHidden == true || child.lastPathComponent.hasPrefix(".")) { continue }
            guard values?.isRegularFile == true,
                  ["md", "markdown"].contains(child.pathExtension.lowercased())
            else { continue }
            let relativePath = child.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            guard needle.isEmpty || relativePath.localizedCaseInsensitiveContains(needle) else { continue }
            matches.append(child)
            if matches.count == limit { break }
        }
        return matches.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
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
