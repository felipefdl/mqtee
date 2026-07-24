import SwiftUI

#if !os(macOS)
struct CompactTopicNodeRow: View {
    @Bindable var node: TopicNode
    var session: SessionStore
    var onNavigate: (TopicNode) -> Void
    var displayName: String? = nil
    var excludedPaths: Set<String> = []

    var body: some View {
        let children = node.children.filter { $0.totalMessageCount > 0 && !excludedPaths.contains($0.fullPath) }
        let count = excludedPaths.isEmpty
            ? node.totalMessageCount
            : countMessagesExcluding(node: node, excluded: excludedPaths)

        if !children.isEmpty {
            DisclosureGroup(isExpanded: $node.isExpanded) {
                ForEach(children) { child in
                    CompactTopicNodeRow(
                        node: child,
                        session: session,
                        onNavigate: onNavigate,
                        excludedPaths: excludedPaths
                    )
                }
            } label: {
                nodeLabel(hasChildren: true, count: count)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if node.isExpanded {
                            onNavigate(node)
                        } else {
                            node.isExpanded = true
                        }
                    }
            }
        } else {
            nodeLabel(hasChildren: false, count: count)
                .contentShape(Rectangle())
                .onTapGesture {
                    onNavigate(node)
                }
        }
    }

    private func nodeLabel(hasChildren: Bool, count: Int) -> some View {
        HStack {
            Image(systemName: hasChildren ? "folder" : "doc.text")
                .foregroundStyle(session.colorForTopic(node.fullPath))
                .contentTransition(.symbolEffect(.replace))

            Text(displayName ?? node.name)
                .lineLimit(1)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
            }

            if hasChildren {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
                    .animation(BrandTheme.springSnappy, value: node.isExpanded)
            }
        }
        .contextMenu {
            topicNodeContextMenu(node: node, session: session)
        }
    }
}
#endif
