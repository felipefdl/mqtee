import Foundation

@Observable
final class TopicNode: Identifiable, Hashable {
    let id: UUID
    let name: String
    let fullPath: String
    var children: [TopicNode]
    @ObservationIgnored var messages: [MQTTMessage]
    var isExpanded: Bool
    /// Retained messages in this subtree. Maintained by `TopicTree`.
    var cachedTotalCount: Int = 0
    /// Messages ever received on this exact topic. Unlike the retained counts it keeps growing when
    /// retention evicts old messages, so "new since last shown" stays detectable at the cap.
    var receivedCount: Int = 0
    /// Messages ever received anywhere in this subtree (same monotonic semantics as `receivedCount`).
    var receivedTotalCount: Int = 0

    var latestMessage: MQTTMessage? {
        messages.last
    }

    var messageCount: Int {
        messages.count
    }

    var totalMessageCount: Int {
        cachedTotalCount
    }

    var hasChildren: Bool {
        !children.isEmpty
    }

    /// Name for row display; empty topic levels (e.g. leading slash) would otherwise render blank.
    var displayName: String {
        name.isEmpty ? String(localized: "(empty)", comment: "Placeholder for an empty topic level") : name
    }

    init(name: String, fullPath: String, children: [TopicNode] = [], messages: [MQTTMessage] = [], isExpanded: Bool = false) {
        self.id = UUID()
        self.name = name
        self.fullPath = fullPath
        self.children = children
        self.messages = messages
        self.isExpanded = isExpanded
    }

    /// Messages received since `shownReceivedCount` was captured, bounded by what is still retained.
    func pendingCount(since shownReceivedCount: Int, includeDescendants: Bool) -> Int {
        let received = includeDescendants ? receivedTotalCount : receivedCount
        let retained = includeDescendants ? totalMessageCount : messageCount
        return min(max(0, received - shownReceivedCount), retained)
    }

    /// Snapshot of the counter `pendingCount(since:includeDescendants:)` compares against.
    func receivedSnapshot(includeDescendants: Bool) -> Int {
        includeDescendants ? receivedTotalCount : receivedCount
    }

    static func == (lhs: TopicNode, rhs: TopicNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
