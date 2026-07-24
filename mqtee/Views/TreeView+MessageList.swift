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

    @State private var currentMessages: [MQTTMessage] = []
    @State private var filteredMessages: [MQTTMessage] = []
    @State private var topicColors: [String: Color] = [:]
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
                selectedMessage = newID.flatMap { id in filteredMessages.first { $0.id == id } }
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
                                Label("\(filteredMessages.count) / \(currentMessages.count) messages", systemImage: "envelope")
                            } else {
                                Label("\(currentMessages.count) messages", systemImage: "envelope")
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
            currentMessages = []
            filteredMessages = []
            topicColors = [:]
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
                ForEach(filteredMessages) { message in
                    let color = topicColors[message.topic] ?? .secondary
                    MessageRowView(message: message, color: color, payloadLineLimit: payloadLineLimit)
                        .transaction { $0.animation = nil }
                        .tag(message.id)
                        .contextMenu {
                            Button("Publish to this topic", systemImage: "paperplane") {
                                session.preparePublishFromContext(topic: message.topic, payload: message.payloadString)
                            }

                            Divider()

                            Button("Copy Message", systemImage: "doc.on.doc") {
                                let text = MessageExportService.formatAsMarkdown(message)
                                MessageExportService.copyToClipboard(text)
                            }

                            Menu("Copy Message As...") {
                                Button("Markdown") {
                                    let text = MessageExportService.formatAsMarkdown(message)
                                    MessageExportService.copyToClipboard(text)
                                }
                                Button("JSON") {
                                    let text = MessageExportService.formatAsJSON(message)
                                    MessageExportService.copyToClipboard(text)
                                }
                                Button("CSV") {
                                    let text = MessageExportService.formatMessagesAsCSV([message])
                                    MessageExportService.copyToClipboard(text)
                                }
                            }

                            Button("Copy Payload Only", systemImage: "text.document") {
                                MessageExportService.copyToClipboard(message.payloadString)
                            }
                        }
                }
                Color.clear
                    .frame(height: 1)
                    .id("bottom-anchor")
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
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
                    if !filteredMessages.isEmpty {
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
                    currentCount: currentMessages.count,
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
        guard let selectedNode else {
            if !currentMessages.isEmpty {
                currentMessages = []
                filteredMessages = []
                topicColors = [:]
            }
            return
        }
        let current = session.messages(for: selectedNode.fullPath, includeDescendants: showAllDescendants)
        let previousCount = currentMessages.count
        guard current.count != previousCount else { return }

        if previousCount == 0 || current.count < previousCount {
            let filtered = messageFilter.isActive ? messageFilter.apply(to: current) : current
            var colors: [String: Color] = [:]
            for message in filtered {
                if colors[message.topic] == nil {
                    colors[message.topic] = session.colorForTopic(message.topic)
                }
            }
            currentMessages = current
            filteredMessages = filtered
            topicColors = colors
        } else {
            let newMessages = Array(current[previousCount...])
            let newFiltered = messageFilter.isActive ? messageFilter.apply(to: newMessages) : newMessages
            currentMessages = current
            if !newFiltered.isEmpty {
                for message in newFiltered {
                    if topicColors[message.topic] == nil {
                        topicColors[message.topic] = session.colorForTopic(message.topic)
                    }
                }
                filteredMessages.append(contentsOf: newFiltered)
            }
        }
    }

    private func applyFilter() {
        let filtered = messageFilter.isActive ? messageFilter.apply(to: currentMessages) : currentMessages
        var colors: [String: Color] = [:]
        for message in filtered {
            if colors[message.topic] == nil {
                colors[message.topic] = session.colorForTopic(message.topic)
            }
        }
        filteredMessages = filtered
        topicColors = colors
    }
}
