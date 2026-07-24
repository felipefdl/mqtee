import SwiftUI

struct TopicNodeRow: View {
    @Bindable var node: TopicNode
    var session: SessionStore
    @Binding var selectedNode: TopicNode?
    var excludedPaths: Set<String> = []

    var body: some View {
        let children = node.children.filter { $0.totalMessageCount > 0 && !excludedPaths.contains($0.fullPath) }
        let count = excludedPaths.isEmpty ? node.totalMessageCount : countMessagesExcluding(node: node, excluded: excludedPaths)

        if !children.isEmpty {
            DisclosureGroup(isExpanded: $node.isExpanded) {
                ForEach(children) { child in
                    TopicNodeRow(node: child, session: session, selectedNode: $selectedNode, excludedPaths: excludedPaths)
                }
            } label: {
                nodeLabel(hasChildren: true, count: count)
            }
            .tag(node)
            .onChange(of: selectedNode) { _, newValue in
                if newValue == node && !node.isExpanded {
                    node.isExpanded = true
                }
            }
        } else {
            nodeLabel(hasChildren: false, count: count)
                .tag(node)
        }
    }

    private func nodeLabel(hasChildren: Bool, count: Int) -> some View {
        HStack {
            Image(systemName: hasChildren ? "folder" : "doc.text")
                .foregroundStyle(session.colorForTopic(node.fullPath))
                .contentTransition(.symbolEffect(.replace))

            Text(node.name)
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
        }
        .contextMenu {
            topicNodeContextMenu(node: node, session: session)
        }
    }
}

struct SubscriptionRootNodeRow: View {
    @Bindable var node: TopicNode
    var basePath: String
    var session: SessionStore
    @Binding var selectedNode: TopicNode?
    var excludedPaths: Set<String>

    var body: some View {
        let children = node.children.filter { $0.totalMessageCount > 0 && !excludedPaths.contains($0.fullPath) }
        let count = excludedPaths.isEmpty ? node.totalMessageCount : countMessagesExcluding(node: node, excluded: excludedPaths)

        if !children.isEmpty {
            DisclosureGroup(isExpanded: $node.isExpanded) {
                ForEach(children) { child in
                    TopicNodeRow(node: child, session: session, selectedNode: $selectedNode, excludedPaths: excludedPaths)
                }
            } label: {
                nodeLabel(hasChildren: true, count: count)
            }
            .tag(node)
            .onChange(of: selectedNode) { _, newValue in
                if newValue == node && !node.isExpanded {
                    node.isExpanded = true
                }
            }
        } else {
            nodeLabel(hasChildren: false, count: count)
                .tag(node)
        }
    }

    private func nodeLabel(hasChildren: Bool, count: Int) -> some View {
        HStack {
            Image(systemName: hasChildren ? "folder" : "doc.text")
                .foregroundStyle(session.colorForTopic(node.fullPath))
                .contentTransition(.symbolEffect(.replace))

            Text(basePath)
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
        }
        .contextMenu {
            topicNodeContextMenu(node: node, session: session)
        }
    }
}

func countMessagesExcluding(node: TopicNode, excluded: Set<String>) -> Int {
    var excludedCount = 0
    for child in node.children where excluded.contains(child.fullPath) {
        excludedCount += child.totalMessageCount
    }
    return node.totalMessageCount - excludedCount
}

@ViewBuilder
func topicNodeContextMenu(node: TopicNode, session: SessionStore) -> some View {
    Button("Publish to this topic", systemImage: "paperplane") {
        session.preparePublishFromContext(topic: node.fullPath)
    }

    Divider()

    Button("Copy Topic Path", systemImage: "doc.on.doc") {
        MessageExportService.copyToClipboard(node.fullPath)
    }

    if node.messageCount > 0 {
        Menu("Copy Messages (\(node.messageCount))") {
            Button("JSON") {
                let text = MessageExportService.formatMessagesAsJSON(node.messages)
                MessageExportService.copyToClipboard(text)
            }
            Button("CSV") {
                let text = MessageExportService.formatMessagesAsCSV(node.messages)
                MessageExportService.copyToClipboard(text)
            }
        }
    }

    if node.hasChildren && node.totalMessageCount > node.messageCount {
        let allDescendantMessages = session.messages(for: node.fullPath, includeDescendants: true)
        Menu("Copy All Messages incl. Children (\(node.totalMessageCount))") {
            Button("JSON") {
                let text = MessageExportService.formatMessagesAsJSON(allDescendantMessages)
                MessageExportService.copyToClipboard(text)
            }
            Button("CSV") {
                let text = MessageExportService.formatMessagesAsCSV(allDescendantMessages)
                MessageExportService.copyToClipboard(text)
            }
        }
    }

    if node.messageCount > 0 || (node.hasChildren && node.totalMessageCount > 0) {
        Divider()

        if node.messageCount > 0 {
            Button("Clear Messages", systemImage: "trash") {
                session.clearMessagesForTopic(node.fullPath)
            }
        }

        if node.hasChildren && node.totalMessageCount > node.messageCount {
            Button("Clear All Messages incl. Children", systemImage: "trash") {
                session.clearMessagesForTopic(node.fullPath)
            }
        }
    }
}
