import SwiftUI

struct OutlineView: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let headings = store.renderedDocument?.headings, !headings.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(headings) { heading in
                                Button {
                                    store.selectedHeadingID = heading.id
                                } label: {
                                    Text(heading.title)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, CGFloat(heading.level - 1) * 11)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                        .background(store.selectedHeadingID == heading.id ? Color.accentColor.opacity(0.14) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                                .id(heading.id)
                                .contextMenu {
                                    Button("复制标题") { store.copyHeading(heading) }
                                    Button("复制位置") { store.copyLocation(heading) }
                                }
                            }
                        }
                        .padding(7)
                    }
                    .onChange(of: store.selectedHeadingID) { _, id in
                        guard let id else { return }
                        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            } else {
                VStack(spacing: 9) {
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 23, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("没有标题")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("当前文档没有可用大纲")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
