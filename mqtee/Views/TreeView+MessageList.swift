import SwiftUI

struct MessageListPanel: View {
    var session: SessionStore
    var selectedNode: TopicNode?
    var showAllDescendants: Bool
    @Binding var selectedMessage: MQTTMessage?
    @Binding var autoScroll: Bool
    @AppStorage("messageListDensity") var densityRawValue = MessageListDensity.compact.rawValue
    @AppStorage("compactPayloadLines") var compactLines = 2
    @AppStorage("comfortablePayloadLines") var comfortableLines = 8

    @State private var list = MessageListState()
    @State private var messageFilter = MessageFilterState()

    private var density: MessageListDensity {
        MessageListDensity(rawValue: densityRawValue) ?? .compact
    }

    private var payloadLineLimit: Int {
        density == .compact ? compactLines : comfortableLines
    }

    private var listSelectionID: Binding<UUID?> {
        Binding(
            get: { selectedMessage?.id },
            set: { newID in
                selectedMessage = newID.flatMap { id in list.filteredMessages.first { $0.id == id } }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let selectedNode {
                        Text(selectedNode.fullPath)
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
                    } else {
                        Text("Messages")
                            #if os(macOS)
                            .font(.headline)
                            #else
                            .font(.subheadline)
                            #endif
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Button {
                    withAnimation(BrandTheme.springSnappy) {
                        densityRawValue = density == .compact
                            ? MessageListDensity.comfortable.rawValue
                            : MessageListDensity.compact.rawValue
                    }
                } label: {
                    Image(systemName: density == .compact
                        ? "rectangle.compress.vertical"
                        : "rectangle.expand.vertical")
                        .accessibilityLabel(density == .compact ? "Switch to comfortable density" : "Switch to compact density")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(density == .compact ? "Switch to comfortable density" : "Switch to compact density")
            }
            #if os(macOS)
            .padding()
            .frame(height: 66)
            #else
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(height: 54)
            #endif

            MessageFilterBar(filter: $messageFilter)

            Divider()

            messageListContent
        }
        .onChange(of: selectedNode) { _, _ in
            list.reset()
            selectedMessage = nil
            autoScroll = true
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
    }

    private var messageListContent: some View {
        ScrollViewReader { proxy in
            List(selection: listSelectionID) {
                ForEach(list.filteredMessages) { message in
                    let color = list.topicColors[message.topic] ?? .secondary
                    MessageRowView(message: message, color: color, payloadLineLimit: payloadLineLimit)
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
            // Recreate the List when it flips between empty and populated: a List that first renders empty keeps
            // stale single-line row heights on macOS.
            .id(list.filteredMessages.isEmpty)
            .defaultScrollAnchor(.bottom)
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
                    selectedNode: selectedNode,
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

    private func updateMessages() {
        list.refresh(node: selectedNode, includeDescendants: showAllDescendants, filter: messageFilter, session: session)
    }

    private func applyFilter() {
        list.applyFilter(messageFilter, session: session)
    }
}
