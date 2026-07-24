import SwiftUI

struct TopicListContent: View {
    @Bindable var session: SessionStore
    @Binding var selectedNode: TopicNode?
    @Binding var showAllDescendants: Bool
    var onCompactNavigate: ((TopicNode) -> Void)? = nil
    @State private var searchText: String = ""
    @State private var cachedRootNodes: [(node: TopicNode, basePath: String)] = []
    @State private var cachedFilteredNodes: [TopicNode] = []
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    static func subscriptionRootNodes(for session: SessionStore) -> [(node: TopicNode, basePath: String)] {
        let basePaths = session.subscriptionBasePaths
        let basePathSet = session.subscriptionBasePathSet

        guard !basePaths.isEmpty, basePaths != [""] else {
            return session.topicTree.root.children
                .filter { $0.totalMessageCount > 0 }
                .map { (node: $0, basePath: $0.name) }
        }

        var results: [(node: TopicNode, basePath: String)] = []

        for basePath in basePaths {
            if basePath.isEmpty { continue }
            if let node = session.topicTree.findNode(at: basePath) {
                if node.totalMessageCount > 0 {
                    results.append((node: node, basePath: basePath))
                }
            }
        }

        if basePathSet.contains("") {
            let existingRootPaths = Set(results.map(\.node.fullPath))
            for child in session.topicTree.root.children where child.totalMessageCount > 0 {
                if !existingRootPaths.contains(child.fullPath) {
                    results.append((node: child, basePath: child.name))
                }
            }
        }

        return results
    }

    private func subscriptionExcludedPaths(from roots: [(node: TopicNode, basePath: String)]) -> Set<String> {
        Set(roots.map(\.node.fullPath))
    }

    private func recomputeRootNodes() {
        cachedRootNodes = Self.subscriptionRootNodes(for: session)
    }

    private func recomputeFilteredNodes() {
        guard !searchText.isEmpty else {
            cachedFilteredNodes = []
            return
        }
        cachedFilteredNodes = session.topicTree.allNodes().filter { node in
            node.fullPath.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.fullPath < $1.fullPath }
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter topics...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))

            Button {
                showAllDescendants.toggle()
            } label: {
                Image(systemName: showAllDescendants ? "rectangle.stack" : "rectangle")
                    .foregroundStyle(showAllDescendants ? .primary : .secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .help(showAllDescendants ? "Showing all descendant messages" : "Showing only this topic's messages")
        }
        .padding(.horizontal)
        .padding(.bottom, 8)

        Divider()

        topicListContent
            .onAppear {
                recomputeRootNodes()
                recomputeFilteredNodes()
            }
            .onChange(of: session.subscriptions) {
                recomputeRootNodes()
            }
            .onChange(of: session.topicTree.treeVersion) {
                recomputeRootNodes()
                if !searchText.isEmpty {
                    recomputeFilteredNodes()
                }
            }
            .onChange(of: searchText) {
                recomputeFilteredNodes()
            }
    }

    @ViewBuilder
    private var topicListContent: some View {
        if !session.topicTree.hasMessages {
            ContentUnavailableView {
                Label("No Topics", systemImage: "tray")
                    .foregroundStyle(.secondary)
            } description: {
                Text("Topics will appear here as messages arrive")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !searchText.isEmpty && cachedFilteredNodes.isEmpty {
            ContentUnavailableView {
                Label("No Matches", systemImage: "magnifyingglass")
                    .foregroundStyle(.secondary)
            } description: {
                Text("No topics match your filter")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            #if !os(macOS)
            if horizontalSizeClass == .compact, let onNavigate = onCompactNavigate {
                compactTopicList(onNavigate: onNavigate)
            } else {
                defaultTopicList
            }
            #else
            defaultTopicList
            #endif
        }
    }

    private var defaultTopicList: some View {
        List(selection: $selectedNode) {
            if searchText.isEmpty {
                let excluded = subscriptionExcludedPaths(from: cachedRootNodes)
                ForEach(cachedRootNodes, id: \.node.id) { entry in
                    SubscriptionRootNodeRow(
                        node: entry.node,
                        basePath: entry.basePath,
                        session: session,
                        selectedNode: $selectedNode,
                        excludedPaths: excluded
                    )
                }
            } else {
                ForEach(cachedFilteredNodes) { node in
                    HStack {
                        Image(systemName: node.hasChildren ? "folder" : "doc.text")
                            .foregroundStyle(session.colorForTopic(node.fullPath))
                        Text(node.fullPath)
                            .lineLimit(1)
                        Spacer()
                        if node.totalMessageCount > 0 {
                            Text("\(node.totalMessageCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.fill.tertiary, in: Capsule())
                        }
                    }
                    .tag(node)
                    .contextMenu {
                        topicNodeContextMenu(node: node, session: session)
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #else
        .listStyle(.plain)
        #endif
    }

    #if !os(macOS)
    private func compactTopicList(onNavigate: @escaping (TopicNode) -> Void) -> some View {
        List {
            if searchText.isEmpty {
                let excluded = subscriptionExcludedPaths(from: cachedRootNodes)
                ForEach(cachedRootNodes, id: \.node.id) { entry in
                    CompactTopicNodeRow(
                        node: entry.node,
                        session: session,
                        onNavigate: onNavigate,
                        displayName: entry.basePath,
                        excludedPaths: excluded
                    )
                }
            } else {
                ForEach(cachedFilteredNodes) { node in
                    HStack {
                        Image(systemName: node.hasChildren ? "folder" : "doc.text")
                            .foregroundStyle(session.colorForTopic(node.fullPath))
                        Text(node.fullPath)
                            .lineLimit(1)
                        Spacer()
                        if node.totalMessageCount > 0 {
                            Text("\(node.totalMessageCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.fill.tertiary, in: Capsule())
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onNavigate(node) }
                    .contextMenu {
                        topicNodeContextMenu(node: node, session: session)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    #endif
}
