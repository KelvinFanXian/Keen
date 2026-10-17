import SwiftUI

@main
struct KeenApp: App {
    @StateObject private var store = WorkspaceStore()

    var body: some Scene {
        Window("Keen", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1320, height: 840)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentMinSize)
        .commands {
            KeenCommands(store: store)
        }

        Settings {
            PreferencesView()
                .environmentObject(store)
        }
    }
}

private struct KeenCommands: Commands {
    @ObservedObject var store: WorkspaceStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开文件…") { store.chooseFile() }
                .keyboardShortcut("o")
            Button("打开文件夹…") { store.chooseFolder() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Divider()
            Button("最近打开的文件…") { store.presentRecentFiles() }
                .keyboardShortcut("e")
                .disabled(store.recentDocuments.isEmpty)
            Divider()
            Button("关闭当前标签页") { store.closeSelectedDocument() }
                .keyboardShortcut("w")
        }
        CommandGroup(after: .pasteboard) {
            Button("在页面中查找…") { store.presentFindBar() }
                .keyboardShortcut("f")
                .disabled(store.selectedDocument == nil)
            Button("搜索工作区文件…") { store.presentWorkspaceSearch() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(store.rootNode == nil)
            Divider()
            Button("复制当前文件绝对路径") { store.copyCurrentFilePath() }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(store.selectedDocument == nil)
        }
        CommandMenu("导航") {
            Button("后退") { store.navigateBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!store.canNavigateBack)
            Button("前进") { store.navigateForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!store.canNavigateForward)
            Divider()
            Button("下一个标签页") { store.selectAdjacentTab(1) }
                .keyboardShortcut(.tab, modifiers: [.control])
                .disabled(store.openDocuments.count < 2)
            Button("上一个标签页") { store.selectAdjacentTab(-1) }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
                .disabled(store.openDocuments.count < 2)
            Divider()
            Menu("打开的文件") {
                ForEach(store.openDocuments) { document in
                    Button {
                        store.select(document)
                    } label: {
                        if store.selectedDocument == document {
                            Label(document.title, systemImage: "checkmark")
                        } else {
                            Text(document.title)
                        }
                    }
                }
            }
            .disabled(store.openDocuments.isEmpty)
            Button("固定当前预览") {
                if let document = store.selectedDocument { store.pin(document) }
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
            .disabled(store.selectedDocument.map(store.isPreview) != true)
            Button("关闭其它文件") {
                if let document = store.selectedDocument { store.closeOthers(keeping: document) }
            }
            .disabled(store.openDocuments.count <= 1)
            Button("关闭右侧文件") {
                if let document = store.selectedDocument { store.closeToRight(of: document) }
            }
            .disabled(store.selectedDocument.map(store.hasDocumentsToRight) != true)
            Divider()
            Button("切换到标签 1") { store.selectTab(at: 1) }.keyboardShortcut("1").disabled(store.openDocuments.count < 1)
            Button("切换到标签 2") { store.selectTab(at: 2) }.keyboardShortcut("2").disabled(store.openDocuments.count < 2)
            Button("切换到标签 3") { store.selectTab(at: 3) }.keyboardShortcut("3").disabled(store.openDocuments.count < 3)
            Button("切换到标签 4") { store.selectTab(at: 4) }.keyboardShortcut("4").disabled(store.openDocuments.count < 4)
            Button("切换到标签 5") { store.selectTab(at: 5) }.keyboardShortcut("5").disabled(store.openDocuments.count < 5)
            Button("切换到标签 6") { store.selectTab(at: 6) }.keyboardShortcut("6").disabled(store.openDocuments.count < 6)
            Button("切换到标签 7") { store.selectTab(at: 7) }.keyboardShortcut("7").disabled(store.openDocuments.count < 7)
            Button("切换到标签 8") { store.selectTab(at: 8) }.keyboardShortcut("8").disabled(store.openDocuments.count < 8)
            Button("切换到标签 9") { store.selectTab(at: 9) }.keyboardShortcut("9").disabled(store.openDocuments.count < 9)
        }
        CommandMenu("阅读") {
            Menu("阅读样式") {
                ForEach(ReadingStyle.allCases) { style in
                    Button {
                        store.readingStyle = style
                    } label: {
                        if store.readingStyle == style {
                            Label(style.label, systemImage: "checkmark")
                        } else {
                            Text(style.label)
                        }
                    }
                }
            }
            Divider()
            Button("增大字号") { store.adjustFontSize(by: 1) }
                .keyboardShortcut("+")
            Button("减小字号") { store.adjustFontSize(by: -1) }
                .keyboardShortcut("-")
            Button("恢复默认字号") { store.resetFontSize() }
                .keyboardShortcut("0")
            Divider()
            Button(store.focusMode ? "退出专注阅读" : "专注阅读") {
                store.focusMode.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            Button(store.showOutline ? "隐藏大纲" : "显示大纲") {
                store.showOutline.toggle()
            }
            .keyboardShortcut("2", modifiers: [.command, .shift])
            Button(store.showExplorer ? "隐藏文件侧栏" : "显示文件侧栏") {
                store.showExplorer.toggle()
            }
            .keyboardShortcut("0", modifiers: [.command, .shift])
            Divider()
            Button(store.vimNavigationEnabled ? "关闭 Vim 风格阅读导航" : "启用 Vim 风格阅读导航") {
                store.vimNavigationEnabled.toggle()
            }
            .keyboardShortcut("v", modifiers: [.command, .option])
        }
    }
}
