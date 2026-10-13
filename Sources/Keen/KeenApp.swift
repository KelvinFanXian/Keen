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
        }
        CommandGroup(after: .pasteboard) {
            Button("复制当前文件绝对路径") { store.copyCurrentFilePath() }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(store.selectedDocument == nil)
        }
        CommandMenu("阅读") {
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
        }
    }
}
