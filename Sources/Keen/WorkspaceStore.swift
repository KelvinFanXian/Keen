import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var rootNode: FileNode?
    @Published var openDocuments: [OpenDocument] = []
    @Published var selectedDocument: OpenDocument?
    @Published private(set) var previewDocumentID: URL?
    @Published var renderedDocument: RenderedDocument?
    @Published var selectedHeadingID: String?
    @Published var showExplorer = true
    @Published var showOutline = true
    @Published var focusMode = false
    @Published var showHiddenFiles = false
    @Published var theme: ReadingTheme = .system
    @Published var readingStyle: ReadingStyle = .swiss
    @Published var fontSize: Double = 15
    @Published var readingWidth: Double = 860
    @Published var errorMessage: String?
    @Published var reloadToken = UUID()
    @Published private(set) var canNavigateBack = false
    @Published private(set) var canNavigateForward = false
    @Published var showFindBar = false
    @Published private(set) var findFocusRequest = UUID()
    @Published private(set) var recentDocuments: [URL] = []
    @Published var showRecentFiles = false
    @Published private(set) var recentWorkspaces: [URL] = []
    @Published var showWorkspaceSearch = false

    private var watcher: FileWatcher?
    private let renderer = MarkdownRenderer()
    private let defaults = UserDefaults.standard
    private var scopedURLs: Set<URL> = []
    private var navigationHistory = NavigationHistory()
    private var recentHistory = WorkspaceRecentDocumentHistory()
    private var workspaceSessions: [String: WorkspaceTabSession] = [:]
    private var recentWorkspaceHistory = RecentWorkspaceHistory()

    init() {
        restoreWorkspaceSessions()
        restoreRecentWorkspaces()
        restoreRecentDocuments()
        restorePreferences()
        restoreWorkspace()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择 Markdown 文件夹"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFolder(url)
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "选择 Markdown 文档"
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!, UTType(filenameExtension: "markdown")!]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFile(url)
    }

    func presentFindBar() {
        showFindBar = true
        findFocusRequest = UUID()
    }

    func presentRecentFiles() {
        if let workspaceURL = rootNode?.url {
            recentHistory.retain(in: workspaceURL) { FileManager.default.fileExists(atPath: $0.path) }
        }
        syncRecentDocuments()
        showRecentFiles = true
    }

    func presentWorkspaceSearch() {
        guard rootNode != nil else { return }
        showWorkspaceSearch = true
    }

    func openRecentFile(_ url: URL) {
        showRecentFiles = false
        openFile(url)
    }

    func selectTab(at position: Int) {
        let index = position - 1
        guard openDocuments.indices.contains(index) else { return }
        select(openDocuments[index])
    }

    func openFolder(_ url: URL) {
        let workspaceURL = url.standardizedFileURL
        if rootNode?.url.standardizedFileURL == workspaceURL {
            rememberWorkspace(workspaceURL)
            return
        }
        persistCurrentWorkspaceSession()
        retainAccess(to: workspaceURL)
        resetWorkspacePresentation()
        rootNode = FileNode(url: workspaceURL, isDirectory: true)
        restoreWorkspaceSession(for: workspaceURL)
        rememberWorkspace(workspaceURL)
        defaults.set(workspaceURL.path, forKey: "lastWorkspace")
        syncRecentDocuments()
    }

    func refreshWorkspace() {
        guard let url = rootNode?.url else { return }
        rootNode = FileNode(url: url, isDirectory: true)
    }

    func revealWorkspaceInFinder() {
        guard let url = rootNode?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func togglePinnedWorkspace(_ url: URL) {
        recentWorkspaceHistory.togglePinned(url)
        syncRecentWorkspaces()
    }

    func removeRecentWorkspace(_ url: URL) {
        recentWorkspaceHistory.remove(url)
        syncRecentWorkspaces()
    }

    func isWorkspacePinned(_ url: URL) -> Bool {
        recentWorkspaceHistory.isPinned(url)
    }

    func openFile(_ url: URL, headingID: String? = nil, pinned: Bool = false) {
        guard ["md", "markdown"].contains(url.pathExtension.lowercased()) else { return }
        retainAccess(to: url)
        let document = OpenDocument(id: url, url: url)

        if openDocuments.contains(document) {
            if pinned { pin(document) }
        } else if !pinned, let previewID = previewDocumentID,
                  let previewIndex = openDocuments.firstIndex(where: { $0.id == previewID }) {
            openDocuments[previewIndex] = document
            previewDocumentID = document.id
        } else {
            openDocuments.append(document)
            previewDocumentID = pinned ? previewDocumentID : document.id
        }
        selectedDocument = document
        rememberRecentDocument(url)
        selectedHeadingID = nil
        load(document)
        selectedHeadingID = headingID
        persistTabs()
    }

    func openLinkedDocument(_ url: URL, headingID: String? = nil) {
        let target = NavigationLocation(url: url, headingID: headingID)
        if let current = currentNavigationLocation, current != target {
            navigationHistory.recordVisit(from: current)
            syncNavigationState()
        }
        openFile(url, headingID: headingID)
    }

    func navigateBack() {
        guard let current = currentNavigationLocation,
              let target = navigationHistory.goBack(from: current) else { return }
        syncNavigationState()
        openFile(target.url, headingID: target.headingID)
    }

    func navigateForward() {
        guard let current = currentNavigationLocation,
              let target = navigationHistory.goForward(from: current) else { return }
        syncNavigationState()
        openFile(target.url, headingID: target.headingID)
    }

    func close(_ document: OpenDocument) {
        guard let index = openDocuments.firstIndex(of: document) else { return }
        openDocuments.remove(at: index)
        if previewDocumentID == document.id { previewDocumentID = nil }
        if selectedDocument == document {
            selectedDocument = openDocuments.indices.contains(index)
                ? openDocuments[index]
                : openDocuments.last
            if let next = selectedDocument { load(next) }
            else { renderedDocument = nil; watcher = nil }
        }
        persistTabs()
    }

    func pin(_ document: OpenDocument) {
        if previewDocumentID == document.id {
            previewDocumentID = nil
            persistTabs()
        }
    }

    func isPreview(_ document: OpenDocument) -> Bool {
        previewDocumentID == document.id
    }

    func closeOthers(keeping document: OpenDocument) {
        guard openDocuments.contains(document) else { return }
        openDocuments = [document]
        selectedDocument = document
        previewDocumentID = nil
        load(document)
        persistTabs()
    }

    func closeToRight(of document: OpenDocument) {
        guard let index = openDocuments.firstIndex(of: document), index + 1 < openDocuments.count else { return }
        let removed = openDocuments[(index + 1)...]
        if let selectedDocument, removed.contains(selectedDocument) {
            self.selectedDocument = document
            load(document)
        }
        if let previewDocumentID, removed.contains(where: { $0.id == previewDocumentID }) {
            self.previewDocumentID = nil
        }
        openDocuments.removeSubrange((index + 1)...)
        persistTabs()
    }

    func hasDocumentsToRight(of document: OpenDocument) -> Bool {
        guard let index = openDocuments.firstIndex(of: document) else { return false }
        return index + 1 < openDocuments.count
    }

    func select(_ document: OpenDocument) {
        guard selectedDocument != document else { return }
        selectedDocument = document
        rememberRecentDocument(document.url)
        load(document)
        persistTabs()
    }

    func refresh() {
        guard let document = selectedDocument else { return }
        load(document, preservePosition: true)
    }

    func handleSelectedFileChange() {
        guard let document = selectedDocument else { return }
        if FileManager.default.fileExists(atPath: document.url.path) {
            load(document, preservePosition: true)
        } else {
            reconcileOpenDocuments()
        }
    }

    func reconcileOpenDocuments() {
        let previousDocuments = openDocuments
        let validDocuments = previousDocuments.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        guard validDocuments.count != previousDocuments.count else { return }

        let previousSelection = selectedDocument
        let previousIndex = previousSelection.flatMap { previousDocuments.firstIndex(of: $0) }
        openDocuments = validDocuments
        if let previewDocumentID, !validDocuments.contains(where: { $0.id == previewDocumentID }) {
            self.previewDocumentID = nil
        }

        if let previousSelection, !validDocuments.contains(previousSelection) {
            if let previousIndex, !validDocuments.isEmpty {
                selectedDocument = validDocuments[min(previousIndex, validDocuments.count - 1)]
            } else {
                selectedDocument = validDocuments.last
            }
            selectedHeadingID = nil
            if let selectedDocument {
                load(selectedDocument)
            } else {
                renderedDocument = nil
                errorMessage = nil
                watcher = nil
            }
        }
        persistTabs()
    }

    func copyCurrentFilePath() {
        guard let path = selectedDocument?.url.path else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    func copyHeading(_ heading: HeadingItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(heading.title, forType: .string)
    }

    func copyLocation(_ heading: HeadingItem) {
        guard let path = selectedDocument?.url.path else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(path):\(heading.line)", forType: .string)
    }

    func adjustFontSize(by delta: Double) {
        fontSize = min(24, max(12, fontSize + delta))
        defaults.set(fontSize, forKey: "fontSize")
    }

    func resetFontSize() { fontSize = 15; defaults.set(fontSize, forKey: "fontSize") }

    func persistPreferences() {
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(readingStyle.rawValue, forKey: "readingStyle")
        defaults.set(fontSize, forKey: "fontSize")
        defaults.set(readingWidth, forKey: "readingWidth")
        defaults.set(showExplorer, forKey: "showExplorer")
        defaults.set(showHiddenFiles, forKey: "showHiddenFiles")
    }

    func handleDroppedURLs(_ urls: [URL]) {
        guard let url = urls.first else { return }
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if isDirectory.boolValue { openFolder(url) } else { openFile(url) }
    }

    private func load(_ document: OpenDocument, preservePosition: Bool = false) {
        guard FileManager.default.fileExists(atPath: document.url.path) else {
            reconcileOpenDocuments()
            return
        }
        do {
            let data = try Data(contentsOf: document.url)
            guard let source = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            renderedDocument = renderer.render(source: source, baseURL: document.url.deletingLastPathComponent())
            errorMessage = nil
            reloadToken = UUID()
            watcher = FileWatcher(url: document.url) { [weak self] in
                Task { @MainActor in self?.handleSelectedFileChange() }
            }
        } catch {
            if !FileManager.default.fileExists(atPath: document.url.path) {
                reconcileOpenDocuments()
                return
            }
            errorMessage = error.localizedDescription
            renderedDocument = nil
        }
    }

    private func restorePreferences() {
        if let raw = defaults.string(forKey: "theme"), let value = ReadingTheme(rawValue: raw) { theme = value }
        if defaults.integer(forKey: "readingStyleVersion") < 3 {
            readingStyle = .swiss
            defaults.set(readingStyle.rawValue, forKey: "readingStyle")
            defaults.set(3, forKey: "readingStyleVersion")
        } else if let raw = defaults.string(forKey: "readingStyle"), let value = ReadingStyle(rawValue: raw) {
            readingStyle = value
        }
        if defaults.object(forKey: "fontSize") != nil { fontSize = defaults.double(forKey: "fontSize") }
        if defaults.object(forKey: "readingWidth") != nil { readingWidth = defaults.double(forKey: "readingWidth") }
        if defaults.object(forKey: "showExplorer") != nil { showExplorer = defaults.bool(forKey: "showExplorer") }
        showHiddenFiles = defaults.bool(forKey: "showHiddenFiles")
    }

    private func restoreRecentDocuments() {
        let stored = defaults.dictionary(forKey: "recentDocumentsByWorkspace") as? [String: [String]] ?? [:]
        recentHistory = WorkspaceRecentDocumentHistory(pathsByWorkspace: stored)
        recentDocuments = []
    }

    private func restoreWorkspaceSessions() {
        if let data = defaults.data(forKey: "workspaceTabSessions"),
           let decoded = try? JSONDecoder().decode([String: WorkspaceTabSession].self, from: data) {
            workspaceSessions = decoded
            return
        }
        guard let workspacePath = defaults.string(forKey: "lastWorkspace") else { return }
        let root = FileNode(url: URL(fileURLWithPath: workspacePath), isDirectory: true)
        let tabs = (defaults.stringArray(forKey: "openTabs") ?? []).filter {
            FileManager.default.fileExists(atPath: $0) && root.contains(URL(fileURLWithPath: $0))
        }
        let selected = defaults.string(forKey: "lastFile").flatMap {
            root.contains(URL(fileURLWithPath: $0)) ? $0 : nil
        }
        if !tabs.isEmpty || selected != nil {
            workspaceSessions[root.url.standardizedFileURL.path] = WorkspaceTabSession(
                openTabPaths: tabs,
                selectedPath: selected
            )
            persistWorkspaceSessions()
        }
        defaults.removeObject(forKey: "openTabs")
        defaults.removeObject(forKey: "lastFile")
    }

    private func restoreRecentWorkspaces() {
        let urls = (defaults.stringArray(forKey: "recentWorkspaces") ?? [])
            .map(URL.init(fileURLWithPath:))
            .filter { url in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            }
        let pinnedURLs = (defaults.stringArray(forKey: "pinnedWorkspaces") ?? []).map(URL.init(fileURLWithPath:))
        recentWorkspaceHistory = RecentWorkspaceHistory(urls: urls, pinnedURLs: pinnedURLs)
        if let lastPath = defaults.string(forKey: "lastWorkspace"), FileManager.default.fileExists(atPath: lastPath) {
            recentWorkspaceHistory.record(URL(fileURLWithPath: lastPath))
        }
        syncRecentWorkspaces()
    }

    private func rememberWorkspace(_ url: URL) {
        recentWorkspaceHistory.record(url)
        syncRecentWorkspaces()
    }

    private func syncRecentWorkspaces() {
        recentWorkspaceHistory.retain { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        recentWorkspaces = recentWorkspaceHistory.urls
        defaults.set(recentWorkspaces.map(\.path), forKey: "recentWorkspaces")
        defaults.set(recentWorkspaceHistory.pinnedURLs.map(\.path), forKey: "pinnedWorkspaces")
    }

    private func rememberRecentDocument(_ url: URL) {
        guard let root = rootNode, root.contains(url) else { return }
        recentHistory.record(url, in: root.url)
        syncRecentDocuments()
    }

    private func syncRecentDocuments() {
        if let workspaceURL = rootNode?.url {
            recentDocuments = recentHistory.documents(in: workspaceURL)
                .filter { FileManager.default.fileExists(atPath: $0.path) }
        } else {
            recentDocuments = []
        }
        defaults.set(recentHistory.pathsByWorkspace, forKey: "recentDocumentsByWorkspace")
    }

    private func restoreWorkspace() {
        if let path = defaults.string(forKey: "lastWorkspace"), FileManager.default.fileExists(atPath: path) {
            openFolder(URL(fileURLWithPath: path))
        }
    }

    private func persistTabs() {
        persistCurrentWorkspaceSession()
    }

    private func persistCurrentWorkspaceSession() {
        guard let root = rootNode else { return }
        let tabs = openDocuments.map(\.url).filter { root.contains($0) && FileManager.default.fileExists(atPath: $0.path) }
        let selectedPath = selectedDocument.flatMap { root.contains($0.url) ? $0.url.path : nil }
        workspaceSessions[root.url.standardizedFileURL.path] = WorkspaceTabSession(
            openTabPaths: tabs.map(\.path),
            selectedPath: selectedPath
        )
        persistWorkspaceSessions()
    }

    private func persistWorkspaceSessions() {
        guard let data = try? JSONEncoder().encode(workspaceSessions) else { return }
        defaults.set(data, forKey: "workspaceTabSessions")
    }

    private func restoreWorkspaceSession(for workspaceURL: URL) {
        guard let session = workspaceSessions[workspaceURL.standardizedFileURL.path] else { return }
        let root = FileNode(url: workspaceURL, isDirectory: true)
        openDocuments = session.openTabPaths.compactMap { path in
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path), root.contains(url) else { return nil }
            return OpenDocument(id: url, url: url)
        }
        guard !openDocuments.isEmpty else { return }
        selectedDocument = session.selectedPath.flatMap { path in
            openDocuments.first { $0.url.path == path }
        } ?? openDocuments.last
        if let selectedDocument { load(selectedDocument) }
    }

    private func resetWorkspacePresentation() {
        openDocuments = []
        selectedDocument = nil
        previewDocumentID = nil
        renderedDocument = nil
        selectedHeadingID = nil
        errorMessage = nil
        watcher = nil
        navigationHistory = NavigationHistory()
        syncNavigationState()
        showFindBar = false
    }

    private func retainAccess(to url: URL) {
        if url.startAccessingSecurityScopedResource() { scopedURLs.insert(url) }
    }

    private var currentNavigationLocation: NavigationLocation? {
        selectedDocument.map { NavigationLocation(url: $0.url, headingID: selectedHeadingID) }
    }

    private func syncNavigationState() {
        canNavigateBack = navigationHistory.canGoBack
        canNavigateForward = navigationHistory.canGoForward
    }
}
