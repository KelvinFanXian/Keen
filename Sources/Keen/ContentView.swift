import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var isDropTargeted = false

    var body: some View {
        HSplitView {
            ExplorerView()
                .environmentObject(store)
                .frame(minWidth: 190, idealWidth: 240, maxWidth: 360)

            VStack(spacing: 0) {
                TabBarView()
                    .environmentObject(store)
                Divider()
                reader
            }
            .frame(minWidth: 500)

            if store.showOutline {
                OutlineView()
                    .environmentObject(store)
                    .frame(minWidth: 190, idealWidth: 240, maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(store.selectedDocument?.title ?? "Keen")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { store.chooseFile() } label: {
                    Label("打开文件", systemImage: "doc")
                }
                Button { store.chooseFolder() } label: {
                    Label("打开文件夹", systemImage: "folder")
                }
                Button { store.showOutline.toggle() } label: {
                    Label("大纲", systemImage: "list.bullet.indent")
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let string = String(data: data, encoding: .utf8), let url = URL(string: string) else { return }
                    Task { @MainActor in store.handleDroppedURLs([url]) }
                }
            }
            return !providers.isEmpty
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .onOpenURL { url in
            if let target = DocumentLinkResolver.resolve(url) {
                store.openFile(target.fileURL, headingID: target.headingID)
            } else {
                store.openFile(url)
            }
        }
        .onChange(of: store.theme) { _, _ in store.persistPreferences() }
        .onChange(of: store.fontSize) { _, _ in store.persistPreferences() }
        .onChange(of: store.readingWidth) { _, _ in store.persistPreferences() }
        .onChange(of: store.showHiddenFiles) { _, _ in store.persistPreferences() }
    }

    @ViewBuilder
    private var reader: some View {
        if let message = store.errorMessage {
            ContentUnavailableView("无法读取文档", systemImage: "exclamationmark.triangle", description: Text(message))
        } else if let rendered = store.renderedDocument, let document = store.selectedDocument {
            MarkdownWebView(
                document: rendered,
                sourceURL: document.url,
                baseURL: document.url.deletingLastPathComponent(),
                theme: store.theme,
                fontSize: store.fontSize,
                readingWidth: store.readingWidth,
                reloadToken: store.reloadToken,
                selectedHeadingID: $store.selectedHeadingID,
                openLocalMarkdown: { url, headingID in
                    store.openFile(url, headingID: headingID)
                }
            )
        } else {
            EmptyReaderView(
                openFile: store.chooseFile,
                openFolder: store.chooseFolder
            )
        }
    }
}

private struct EmptyReaderView: View {
    let openFile: () -> Void
    let openFolder: () -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor.opacity(0.09))
                        .frame(width: 68, height: 68)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.bottom, 20)

                Text("打开 Markdown 文档")
                    .font(.system(size: 22, weight: .semibold))
                Text("选择文档或项目文件夹，也可以直接从 Finder 拖入。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    Button("打开文件…", action: openFile)
                        .frame(minWidth: 92)
                    Button("打开文件夹…", action: openFolder)
                        .frame(minWidth: 106)
                }
                .controlSize(.large)
                .padding(.top, 22)

                Text("⌘O 打开文件  ·  ⇧⌘O 打开文件夹")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 14)
            }
            .padding(40)
        }
    }
}

private struct TabBarView: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        if !store.openDocuments.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(store.openDocuments) { document in
                            HStack(spacing: 6) {
                                Button(document.title) { store.select(document) }
                                    .buttonStyle(.plain)
                                    .lineLimit(1)
                                Button { store.close(document) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(store.selectedDocument == document ? Color.accentColor.opacity(0.13) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .id(document.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
                .frame(height: 39)
                .background(.bar)
                .onAppear { revealSelection(proxy) }
                .onChange(of: store.selectedDocument?.id) { _, _ in revealSelection(proxy) }
            }
        }
    }

    private func revealSelection(_ proxy: ScrollViewProxy) {
        guard let id = store.selectedDocument?.id else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            proxy.scrollTo(id, anchor: .trailing)
        }
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        Form {
            Picker("外观", selection: $store.theme) {
                ForEach(ReadingTheme.allCases) { theme in Text(theme.label).tag(theme) }
            }
            Slider(value: $store.fontSize, in: 12...24, step: 1) {
                Text("正文大小")
            } minimumValueLabel: { Text("12") } maximumValueLabel: { Text("24") }
            Slider(value: $store.readingWidth, in: 640...1200, step: 20) {
                Text("阅读宽度")
            }
            Toggle("显示隐藏文件", isOn: $store.showHiddenFiles)
        }
        .padding(20)
        .frame(width: 420)
    }
}
