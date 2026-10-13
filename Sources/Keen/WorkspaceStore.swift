import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var rootNode: FileNode?
    @Published var openDocuments: [OpenDocument] = []
    @Published var selectedDocument: OpenDocument?
    @Published var renderedDocument: RenderedDocument?
    @Published var selectedHeadingID: String?
    @Published var showOutline = true
    @Published var showHiddenFiles = false
    @Published var theme: ReadingTheme = .system
    @Published var fontSize: Double = 16
    @Published var readingWidth: Double = 900
    @Published var errorMessage: String?
    @Published var reloadToken = UUID()

    private var watcher: FileWatcher?
    private let renderer = MarkdownRenderer()
    private let defaults = UserDefaults.standard
    private var scopedURLs: Set<URL> = []

    init() {
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

    func openFolder(_ url: URL) {
        retainAccess(to: url)
        rootNode = FileNode(url: url, isDirectory: true)
        defaults.set(url.path, forKey: "lastWorkspace")
    }

    func openFile(_ url: URL, headingID: String? = nil) {
        guard ["md", "markdown"].contains(url.pathExtension.lowercased()) else { return }
        retainAccess(to: url)
        let document = OpenDocument(id: url, url: url)
        if !openDocuments.contains(document) { openDocuments.append(document) }
        selectedDocument = document
        selectedHeadingID = nil
        load(document)
        selectedHeadingID = headingID
        persistTabs()
    }

    func close(_ document: OpenDocument) {
        guard let index = openDocuments.firstIndex(of: document) else { return }
        openDocuments.remove(at: index)
        if selectedDocument == document {
            selectedDocument = openDocuments.indices.contains(index)
                ? openDocuments[index]
                : openDocuments.last
            if let next = selectedDocument { load(next) }
            else { renderedDocument = nil; watcher = nil }
        }
        persistTabs()
    }

    func select(_ document: OpenDocument) {
        guard selectedDocument != document else { return }
        selectedDocument = document
        load(document)
    }

    func refresh() {
        guard let document = selectedDocument else { return }
        load(document, preservePosition: true)
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

    func resetFontSize() { fontSize = 16; defaults.set(fontSize, forKey: "fontSize") }

    func persistPreferences() {
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(fontSize, forKey: "fontSize")
        defaults.set(readingWidth, forKey: "readingWidth")
        defaults.set(showHiddenFiles, forKey: "showHiddenFiles")
    }

    func handleDroppedURLs(_ urls: [URL]) {
        guard let url = urls.first else { return }
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if isDirectory.boolValue { openFolder(url) } else { openFile(url) }
    }

    private func load(_ document: OpenDocument, preservePosition: Bool = false) {
        do {
            let data = try Data(contentsOf: document.url)
            guard let source = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            renderedDocument = renderer.render(source: source, baseURL: document.url.deletingLastPathComponent())
            errorMessage = nil
            reloadToken = UUID()
            watcher = FileWatcher(url: document.url) { [weak self] in
                Task { @MainActor in self?.refresh() }
            }
            defaults.set(document.url.path, forKey: "lastFile")
        } catch {
            errorMessage = error.localizedDescription
            renderedDocument = nil
        }
    }

    private func restorePreferences() {
        if let raw = defaults.string(forKey: "theme"), let value = ReadingTheme(rawValue: raw) { theme = value }
        if defaults.object(forKey: "fontSize") != nil { fontSize = defaults.double(forKey: "fontSize") }
        if defaults.object(forKey: "readingWidth") != nil { readingWidth = defaults.double(forKey: "readingWidth") }
        showHiddenFiles = defaults.bool(forKey: "showHiddenFiles")
    }

    private func restoreWorkspace() {
        if let path = defaults.string(forKey: "lastWorkspace"), FileManager.default.fileExists(atPath: path) {
            openFolder(URL(fileURLWithPath: path))
        }
        let paths = defaults.stringArray(forKey: "openTabs") ?? []
        for path in paths where FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            let document = OpenDocument(id: url, url: url)
            openDocuments.append(document)
        }
        if let lastPath = defaults.string(forKey: "lastFile"),
           let document = openDocuments.first(where: { $0.url.path == lastPath }) {
            selectedDocument = document
            load(document)
        }
    }

    private func persistTabs() {
        defaults.set(openDocuments.map(\.url.path), forKey: "openTabs")
    }

    private func retainAccess(to url: URL) {
        if url.startAccessingSecurityScopedResource() { scopedURLs.insert(url) }
    }
}
