import SwiftUI

enum SidebarMode {
    case topics
    case subscriptions
}

struct TreeView: View {
    @Bindable var session: SessionStore
    var folder: ConnectionFolder? = nil
    @Binding var showPublishPanel: Bool
    @State var selectedNode: TopicNode?
    @State var showAllDescendants: Bool = true
    @State var sidebarMode: SidebarMode =
        ProcessInfo.processInfo.arguments.contains("--screenshot-subscriptions") ? .subscriptions : .topics
    @State var selectedMessage: MQTTMessage?
    @State var autoScroll: Bool = true
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSidebar: Bool = true
    @State private var publishSplitRatio: CGFloat = 0.5
    @State private var publishDragStartRatio: CGFloat = 0.5
    @State private var publishColumnHeight: CGFloat = 0
    #endif

    var body: some View {
        treeContent
            .background {
                TreeVersionObserver(
                    session: session,
                    selectedNode: $selectedNode
                )
            }
    }

    var messageListPanel: some View {
        MessageListPanel(
            session: session,
            selectedNode: selectedNode,
            showAllDescendants: showAllDescendants,
            selectedMessage: $selectedMessage,
            autoScroll: $autoScroll
        )
    }

    @ViewBuilder
    private var treeContent: some View {
        #if os(macOS)
        NavigationSplitView {
            topicTreeSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 340)
        } detail: {
            HSplitView {
                messageListPanel
                    .frame(minWidth: 250, idealWidth: 370, maxWidth: 420)
                VSplitView {
                    payloadDetailPanel
                        .frame(minWidth: 200, idealWidth: 300)
                        .layoutPriority(1)
                    if showPublishPanel {
                        PublishPanelContent(session: session, isPinned: true) {
                            showPublishPanel = false
                        }
                        .frame(minHeight: 325, idealHeight: 325)
                    }
                }
            }
        }
        .focusedSceneValue(\.sidebarMode, $sidebarMode)
        .focusedSceneValue(\.selectedTopicNode, selectedNode)
        .focusedSceneValue(\.selectedMessage, selectedMessage)
        #else
        if horizontalSizeClass == .compact {
            compactContent
        } else {
            regularContent
        }
        #endif
    }

    #if !os(macOS)
    private var compactContent: some View {
        topicTreeSidebar(onCompactNavigate: { node in selectedNode = node })
            .navigationDestination(item: $selectedNode) { node in
                MessageDetailView(node: node, session: session, showAllDescendants: showAllDescendants, folder: folder)
            }
    }

    private var regularContent: some View {
        HStack(spacing: 0) {
            if showSidebar {
                topicTreeSidebar()
                    .frame(width: 240)
                Divider()
            }
            messageListPanel
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 380)
            Divider()
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    if abs(newHeight - publishColumnHeight) > 1 {
                        publishColumnHeight = newHeight
                    }
                }
                .overlay {
                    if showPublishPanel {
                        let available = max(publishColumnHeight - 12, 200)
                        let detailHeight = min(max(80, available * publishSplitRatio), available - 120)
                        let panelHeight = available - detailHeight
                        VStack(spacing: 0) {
                            payloadDetailPanel
                                .frame(height: detailHeight)
                            publishResizableDivider
                            PublishPanelContent(session: session, isPinned: true) {
                                showPublishPanel = false
                            }
                            .frame(height: panelHeight)
                        }
                    } else {
                        payloadDetailPanel
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation { showSidebar.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                }
            }
        }
    }

    private var publishResizableDivider: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [.black.opacity(0.1), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 4)
                .allowsHitTesting(false)
            }
            .overlay {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 36, height: 4)
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let newRatio = publishDragStartRatio + value.translation.height / publishColumnHeight
                        publishSplitRatio = min(max(newRatio, 0.15), 0.85)
                    }
                    .onEnded { _ in
                        publishDragStartRatio = publishSplitRatio
                    }
            )
    }
    #endif

    func topicTreeSidebar(onCompactNavigate: ((TopicNode) -> Void)? = nil) -> some View {
        VStack(spacing: 0) {
            if sidebarMode == .topics {
                TopicListContent(
                    session: session,
                    selectedNode: $selectedNode,
                    showAllDescendants: $showAllDescendants,
                    onCompactNavigate: onCompactNavigate
                )
            } else {
                Divider()
                SubscriptionListContent(session: session)
            }

            Divider()

            SidebarSegmentBar(
                session: session,
                sidebarMode: $sidebarMode
            )

            SubscriptionBar(
                mqttVersion: session.connection.mqttVersion,
                onSubscribe: { topic, qos, noLocal, retainAsPublished, retainHandling in
                    session.subscribe(
                        to: topic,
                        qos: qos,
                        noLocal: noLocal,
                        retainAsPublished: retainAsPublished,
                        retainHandling: retainHandling
                    )
                }
            )
        }
    }

}

private struct SubscriptionListContent: View {
    @Bindable var session: SessionStore

    var body: some View {
        if session.subscriptions.isEmpty {
            ContentUnavailableView {
                Label("No Subscriptions", systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
            } description: {
                Text("Subscribe to a topic using the bar below")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(session.subscriptions) { subscription in
                    SubscriptionRow(subscription: subscription) {
                        session.unsubscribe(from: subscription.id)
                    }
                    .contextMenu {
                        Button("Copy Topic", systemImage: "doc.on.doc") {
                            MessageExportService.copyToClipboard(subscription.topic)
                        }

                        Divider()

                        Button("Clear Messages", systemImage: "trash") {
                            session.clearMessagesForSubscription(subscription)
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
    }
}

// Zero-size view isolating topicTree observation from the TreeView body.
// Prevents treeVersion/hasMessages changes from invalidating the entire view hierarchy.
private struct TreeVersionObserver: View {
    var session: SessionStore
    @Binding var selectedNode: TopicNode?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: session.topicTree.hasMessages) { _, hasMessages in
                if !hasMessages {
                    selectedNode = nil
                }
            }
    }
}

#Preview {
    TreeView(session: SessionStore.preview(), showPublishPanel: .constant(false))
        .frame(width: 900, height: 600)
}
