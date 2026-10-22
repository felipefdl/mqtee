import SwiftUI

struct MessageDetailView: View {
    var node: TopicNode?
    var session: SessionStore
    var showAllDescendants: Bool
    var folder: ConnectionFolder? = nil
    @State private var selectedMessage: MQTTMessage?
    @State private var autoScroll: Bool = true
    @State private var messageFilter = MessageFilterState()
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var splitRatio: CGFloat = 0.5
    @State private var totalHeight: CGFloat = 0
    @State private var showStatusSheet: Bool = false
    #endif

    @State private var list = MessageListState()

    private var listSelectionID: Binding<UUID?> {
        Binding(
            get: { selectedMessage?.id },
            set: { newID in
                selectedMessage = newID.flatMap { id in list.filteredMessages.first { $0.id == id } }
            }
        )
    }

    #if !os(macOS)
    private var compactStatusDotColor: Color {
        if session.isConnected { return .green }
        if session.isConnecting { return .yellow }
        return .red
    }

    #endif

    var body: some View {
        messageDetailContent
            .onChange(of: node) { _, _ in
                updateMessages()
            }
            .onChange(of: showAllDescendants) { _, _ in
                updateMessages()
            }
            .onChange(of: messageFilter) { _, _ in
                applyFilter()
            }
            .onAppear {
                updateMessages()
            }
            #if os(macOS)
            .focusedSceneValue(\.selectedMessage, selectedMessage)
            #else
            .toolbar {
                if horizontalSizeClass == .compact {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            if let folder {
                                Circle()
                                    .fill(folder.color.color)
                                    .frame(width: 8, height: 8)
                            }
                            Text(session.connection.name)
                                .lineLimit(1)
                                .font(.callout)
                            Circle()
                                .fill(compactStatusDotColor)
                                .frame(width: 8, height: 8)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { showStatusSheet = true }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(session.statusLabel)
                        .accessibilityAddTraits(.isButton)
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            session.showPublishPopover = true
                        } label: {
                            Label("Publish", systemImage: "paperplane")
                        }
                    }
                }
            }
            .sheet(isPresented: $showStatusSheet) {
                ConnectionStatusSheet(session: session, folder: folder)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            #endif
    }

    @ViewBuilder
    private var messageDetailContent: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            #if os(macOS)
            HSplitView {
                messageListView
                    .frame(minWidth: 180, idealWidth: 250)

                payloadView
                    .frame(minWidth: 250)
            }
            #else
            Color.clear
                .frame(maxHeight: .infinity)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    if abs(newHeight - totalHeight) > 1 {
                        totalHeight = newHeight
                    }
                }
                .overlay {
                    VStack(spacing: 0) {
                        let available = max(totalHeight - 12, 160)
                        let listHeight = min(max(80, available * splitRatio), available - 80)
                        let payloadHeight = available - listHeight

                        messageListView
                            .frame(height: listHeight)

                        SplitResizeHandle(splitRatio: $splitRatio, totalHeight: totalHeight)

                        payloadView
                            .frame(height: payloadHeight)
                    }
                }

            if horizontalSizeClass == .compact {
                LogStatusBarView(logStore: LogStore.shared, connectionId: session.connection.id) {
                    session.showLogSheet = true
                }
            }
            #endif
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let node = node {
                    Text(node.fullPath)
                        #if os(macOS)
                        .font(.headline)
                        #else
                        .font(.subheadline)
                        #endif
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Group {
                        if messageFilter.isActive {
                            Label("\(list.filteredMessages.count) / \(list.currentMessages.count) messages", systemImage: "envelope")
                        } else {
                            Label("\(list.currentMessages.count) messages", systemImage: "envelope")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            #if os(macOS)
            Button {
                session.showPublishPopover.toggle()
            } label: {
                Label("Publish Message", systemImage: "paperplane")
            }
            .buttonStyle(.glassProminent)
            .fixedSize()
            .popover(isPresented: Bindable(session).showPublishPopover, arrowEdge: .bottom) {
                PublishPanelContent(session: session)
                    .frame(width: 500, height: 380)
            }
            #endif
        }
        #if os(macOS)
        .padding()
        #else
        .padding(.horizontal)
        .padding(.vertical, 8)
        #endif
    }

    private var messageListView: some View {
        VStack(spacing: 0) {
            MessageFilterBar(filter: $messageFilter)
            Divider()
            ScrollViewReader { proxy in
                List(selection: listSelectionID) {
                    ForEach(list.filteredMessages) { message in
                        MessageRowView(message: message, color: list.topicColors[message.topic] ?? .secondary)
                            .transaction { $0.animation = nil }
                            .tag(message.id)
                            .contextMenu { MessageContextMenu(message: message, session: session) }
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("bottom-anchor")
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                .listStyle(.plain)
                // A List that first renders empty and is then populated keeps stale (single-line) row heights on macOS;
                // recreating it when it flips between empty and populated makes rows measure at full height.
                .id(list.filteredMessages.isEmpty)
                .defaultScrollAnchor(.bottom)
                .onChange(of: node) { _, _ in
                    selectedMessage = nil
                    autoScroll = true
                }
                .background {
                    MessageVersionObserver(
                        session: session,
                        autoScroll: $autoScroll,
                        onUpdate: { updateMessages() },
                        onScroll: { proxy.scrollTo("bottom-anchor", anchor: .bottom) }
                    )
                }
                .onChange(of: selectedMessage) { _, newValue in
                    if newValue != nil { autoScroll = false }
                }
                .onChange(of: autoScroll) { oldValue, newValue in
                    if !oldValue && newValue {
                        updateMessages()
                        if !list.filteredMessages.isEmpty {
                            Task { @MainActor in
                                proxy.scrollTo("bottom-anchor", anchor: .bottom)
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    PendingCountOverlay(
                        selectedNode: node,
                        showAllDescendants: showAllDescendants,
                        shownReceivedCount: list.shownReceivedCount,
                        autoScroll: autoScroll,
                        onShowNew: { updateMessages() },
                        onAutoScroll: {
                            selectedMessage = nil
                            autoScroll = true
                        }
                    )
                }
                #if os(macOS)
                .onExitCommand {
                    selectedMessage = nil
                    autoScroll = true
                }
                #endif
            }
        }
    }

    private var payloadView: some View {
        PayloadDisplayView(message: selectedMessage)
    }

    private func updateMessages() {
        list.refresh(node: node, includeDescendants: showAllDescendants, filter: messageFilter, session: session)
    }

    private func applyFilter() {
        list.applyFilter(messageFilter, session: session)
    }
}
