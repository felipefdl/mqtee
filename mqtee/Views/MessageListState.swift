import SwiftUI

/// Messages shown by a message list (topic detail or tree panel), refreshed from the session.
struct MessageListState {
    private(set) var currentMessages: [MQTTMessage] = []
    private(set) var filteredMessages: [MQTTMessage] = []
    private(set) var topicColors: [String: Color] = [:]
    /// The node's received counter at the last refresh; `PendingCountOverlay` counts arrivals after it.
    private(set) var shownReceivedCount = 0

    mutating func reset() {
        guard !currentMessages.isEmpty || !filteredMessages.isEmpty || !topicColors.isEmpty else { return }
        currentMessages = []
        filteredMessages = []
        topicColors = [:]
    }

    /// Reloads the node's messages. Appends when the previous list is still a prefix; rebuilds when
    /// retention dropped older messages or the selection changed.
    mutating func refresh(
        node: TopicNode?,
        includeDescendants: Bool,
        filter: MessageFilterState,
        session: SessionStore
    ) {
        guard let node else {
            reset()
            return
        }
        shownReceivedCount = node.receivedSnapshot(includeDescendants: includeDescendants)
        let current = session.messages(for: node.fullPath, includeDescendants: includeDescendants)
        let previousCount = currentMessages.count
        if previousCount == 0 && current.isEmpty { return }
        let isAppendOnly = previousCount > 0
            && current.count >= previousCount
            && current[0].id == currentMessages[0].id
            && current[previousCount - 1].id == currentMessages[previousCount - 1].id
        if isAppendOnly && current.count == previousCount { return }

        if !isAppendOnly {
            currentMessages = current
            applyFilter(filter, session: session)
            return
        }

        let newMessages = Array(current[previousCount...])
        let newFiltered = filter.isActive ? filter.apply(to: newMessages) : newMessages
        currentMessages = current
        guard !newFiltered.isEmpty else { return }
        for message in newFiltered where topicColors[message.topic] == nil {
            topicColors[message.topic] = session.colorForTopic(message.topic)
        }
        filteredMessages.append(contentsOf: newFiltered)
    }

    mutating func applyFilter(_ filter: MessageFilterState, session: SessionStore) {
        let filtered = filter.isActive ? filter.apply(to: currentMessages) : currentMessages
        var colors: [String: Color] = [:]
        for message in filtered where colors[message.topic] == nil {
            colors[message.topic] = session.colorForTopic(message.topic)
        }
        filteredMessages = filtered
        topicColors = colors
    }
}
