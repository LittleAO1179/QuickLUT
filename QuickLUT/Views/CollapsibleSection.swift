import SwiftUI

/// 可折叠分区容器：标题行点击展开/收起，状态用 AppStorage 持久化
struct CollapsibleSection<Content: View>: View {
    let title: String
    let storageKey: String
    @ViewBuilder let content: () -> Content

    @AppStorage private var isExpanded: Bool

    init(_ title: String, key: String, defaultExpanded: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.storageKey = key
        self.content = content
        _isExpanded = AppStorage(wrappedValue: defaultExpanded, "section.\(key).expanded")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.rowSpacing) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: LayoutMetrics.rowSpacing) {
                    content()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}
