import Foundation
import SwiftUI

@MainActor
@Observable
final class SessionStore {
    var connection: Connection
    var isConnected: Bool = false
    var isConnecting: Bool = false
    var connectionError: String?
    var connectedSince: Date?
    var subscriptions: [Subscription] = []
    @ObservationIgnored var messages: [MQTTMessage] = []
    var topicTree: TopicTree = TopicTree()
    var messageVersion: Int = 0
    var publishTabs: [PublishTab] = []
    var activePublishTabId: UUID?
    var showPublishPopover: Bool = false
    var showLogSheet: Bool = false
    var triggerPublish: Bool = false
    var triggerPrettify: Bool = false

    let mqttService = MQTTService()
    var credentials: ConnectionCredentials?
    let persistenceService = SessionPersistenceService.shared
    let logStore = LogStore.shared
    let maxMessages: Int
    let batchLogThreshold: Int
    var isHighThroughput: Bool { messageBuffer.count > batchLogThreshold }
    @ObservationIgnored var messagesByTopic: [String: [MQTTMessage]] = [:]
    @ObservationIgnored var cachedTopicMessages: [String: [MQTTMessage]] = [:]
    var pendingReconnect: Bool = false
    var reconnectTask: Task<Void, Never>?
    var reconnectAttempt: Int = 0
    var isReconnecting: Bool = false
    // Settings are read from UserDefaults at access time, not via @AppStorage,
    // because SessionStore is not a View. Changes in Settings take effect on next access.
    var autoReconnectEnabled: Bool {
        UserDefaults.standard.object(forKey: "autoReconnect") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "autoReconnect")
    }
    var reconnectIntervalSeconds: Int {
        let value = UserDefaults.standard.integer(forKey: "reconnectInterval")
        return value > 0 ? value : 5
    }
    @ObservationIgnored var messageBuffer: [MQTTMessage] = []
    @ObservationIgnored var messageFlushTask: Task<Void, Never>?
    @ObservationIgnored var pendingUIUpdate: Bool = false
    @ObservationIgnored var uiFlushTask: Task<Void, Never>?
    @ObservationIgnored var topicColorCache: [String: Color] = [:]
    var isStopped: Bool = false

    init(connection: Connection) {
        self.connection = connection
        let maxMsgs = UserDefaults.standard.integer(forKey: "maxMessagesInMemory")
        self.maxMessages = maxMsgs > 0 ? maxMsgs : 10000
        let batchThreshold = UserDefaults.standard.integer(forKey: "batchLogThreshold")
        self.batchLogThreshold = batchThreshold > 0 ? batchThreshold : 20
        mqttService.delegate = self
    }

    func applyPersistedData(session: PersistedSession?, publishTabs: PersistedPublishTabs?) {
        if let session {
            subscriptions = session.subscriptions
            ensureSubscriptionTopicsInTree()
        }

        if let publishTabs {
            self.publishTabs = publishTabs.tabs
            self.activePublishTabId = publishTabs.activeTabId
        }

        if self.publishTabs.isEmpty {
            let tab = PublishTab()
            self.publishTabs.append(tab)
            self.activePublishTabId = tab.id
        }
    }

    func messages(for topicPath: String, includeDescendants: Bool) -> [MQTTMessage] {
        if includeDescendants {
            let cacheKey = topicPath + ":descendants"
            if let cached = cachedTopicMessages[cacheKey] {
                return cached
            }
            let prefix = topicPath + "/"
            var result: [MQTTMessage] = []
            for (topic, msgs) in messagesByTopic {
                if topic == topicPath || topic.hasPrefix(prefix) {
                    result.append(contentsOf: msgs)
                }
            }
            result.sort { $0.timestamp < $1.timestamp }
            cachedTopicMessages[cacheKey] = result
            return result
        } else {
            return messagesByTopic[topicPath] ?? []
        }
    }

    func invalidateMessageCache() {
        cachedTopicMessages.removeAll(keepingCapacity: true)
    }

    func rebuildMessagesByTopic() {
        messagesByTopic.removeAll(keepingCapacity: true)
        for message in messages {
            messagesByTopic[message.topic, default: []].append(message)
        }
    }

    func ensureSubscriptionTopicsInTree() {
        for subscription in subscriptions {
            topicTree.ensureTopic(subscription.topic)
        }
    }

    func persistSubscriptions() {
        guard connection.persistSession else { return }
        persistenceService.updateSubscriptions(for: connection.id, subscriptions: subscriptions)
    }

    func topicMatchesPattern(topic: String, pattern: String) -> Bool {
        mqttTopicMatchesPattern(topic: topic, pattern: pattern)
    }

    // MARK: - Publish Tabs

    var activePublishTab: PublishTab? {
        if let activePublishTabId, let tab = publishTabs.first(where: { $0.id == activePublishTabId }) {
            return tab
        }
        return publishTabs.first
    }

    func addPublishTab() {
        let tab = PublishTab()
        publishTabs.append(tab)
        activePublishTabId = tab.id
        persistPublishTabs()
    }

    func addPublishTab(topic: String, payload: String = "", payloadFormat: PublishPayloadFormat = .text) {
        let tab = PublishTab(topic: topic, payload: payload, payloadFormat: payloadFormat)
        publishTabs.append(tab)
        activePublishTabId = tab.id
        persistPublishTabs()
    }

    func preparePublishFromContext(topic: String, payload: String = "") {
        let format: PublishPayloadFormat = if !payload.isEmpty,
            let data = payload.data(using: .utf8),
            (try? JSONSerialization.jsonObject(with: data)) != nil {
            .json
        } else {
            .text
        }
        addPublishTab(topic: topic, payload: payload, payloadFormat: format)
        showPublishPopover = true
    }

    func removePublishTab(_ tabId: UUID) {
        publishTabs.removeAll { $0.id == tabId }
        if activePublishTabId == tabId {
            activePublishTabId = publishTabs.first?.id
        }
        if publishTabs.isEmpty {
            addPublishTab()
            return
        }
        persistPublishTabs()
    }

    func closeAllPublishTabs() {
        publishTabs.removeAll()
        addPublishTab()
    }

    func updatePublishTab(_ tab: PublishTab) {
        guard let index = publishTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        var updated = tab
        updated.lastModified = Date()
        publishTabs[index] = updated
        persistPublishTabs()
    }

    func selectPublishTab(_ tabId: UUID) {
        activePublishTabId = tabId
        persistPublishTabs()
    }


    private func persistPublishTabs() {
        persistenceService.savePublishTabs(for: connection.id, tabs: publishTabs, activeTabId: activePublishTabId)
    }

    func colorForTopic(_ topic: String) -> Color {
        if let cached = topicColorCache[topic] {
            return cached
        }
        var bestMatch: Subscription?
        var bestScore = -1
        for subscription in subscriptions {
            if topicMatchesPattern(topic: topic, pattern: subscription.topic) {
                let score = patternSpecificity(subscription.topic)
                if score > bestScore {
                    bestScore = score
                    bestMatch = subscription
                }
            }
        }
        let color = bestMatch?.color.color ?? .secondary
        topicColorCache[topic] = color
        return color
    }

    private func patternSpecificity(_ pattern: String) -> Int {
        let parts = pattern.split(separator: "/", omittingEmptySubsequences: false)
        return parts.reduce(0) { score, part in
            if part == "#" { return score }
            if part == "+" { return score + 1 }
            return score + 2
        }
    }

    // MARK: - Subscription Base Paths

    var subscriptionBasePaths: [String] {
        let paths = subscriptions.map { subscription -> String in
            let parts = subscription.topic.split(separator: "/", omittingEmptySubsequences: false)
            let prefix = parts.prefix { $0 != "#" && $0 != "+" }
            return prefix.joined(separator: "/")
        }
        return Array(Set(paths)).sorted()
    }

    var subscriptionBasePathSet: Set<String> {
        Set(subscriptions.map { subscription -> String in
            let parts = subscription.topic.split(separator: "/", omittingEmptySubsequences: false)
            let prefix = parts.prefix { $0 != "#" && $0 != "+" }
            return prefix.joined(separator: "/")
        })
    }

    // MARK: - Demo Data for Preview

    static func preview() -> SessionStore {
        let connection = Connection(
            name: "Local Broker",
            host: "localhost",
            port: 1883
        )
        let store = SessionStore(connection: connection)
        store.isConnected = true
        store.connectedSince = Date().addingTimeInterval(-3725)

        store.subscriptions = [
            Subscription(topic: "sensors/#", qos: .atLeastOnce, color: .blue),
            Subscription(topic: "home/+/temperature", qos: .atMostOnce, color: .green),
            Subscription(topic: "alerts/#", qos: .exactlyOnce, color: .red)
        ]

        let sampleMessages: [(String, String)] = [
            ("sensors/living-room/temperature", "{\"value\": 22.5, \"unit\": \"C\"}"),
            ("sensors/bedroom/humidity", "{\"value\": 45, \"unit\": \"%\"}"),
            ("home/kitchen/temperature", "{\"value\": 24.1, \"unit\": \"C\"}"),
            ("alerts/smoke-detector", "{\"status\": \"OK\", \"battery\": 95}"),
            ("sensors/living-room/motion", "{\"detected\": false}"),
            ("sensors/garage/door", "{\"state\": \"closed\"}"),
            ("home/bathroom/temperature", "{\"value\": 21.0, \"unit\": \"C\"}"),
            ("alerts/water-leak", "{\"status\": \"OK\", \"location\": \"basement\"}")
        ]

        for (index, (topic, payload)) in sampleMessages.enumerated() {
            let message = MQTTMessage(
                topic: topic,
                payloadString: payload,
                qos: .atMostOnce,
                retained: false,
                timestamp: Date().addingTimeInterval(Double(-index * 30))
            )
            store.receiveMessage(message)
        }

        return store
    }
}
