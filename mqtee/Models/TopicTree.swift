import Foundation

@Observable
final class TopicNode: Identifiable, Hashable {
    let id: UUID
    let name: String
    let fullPath: String
    var children: [TopicNode]
    @ObservationIgnored var messages: [MQTTMessage]
    var isExpanded: Bool
    fileprivate(set) var cachedTotalCount: Int = 0

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

    init(name: String, fullPath: String, children: [TopicNode] = [], messages: [MQTTMessage] = [], isExpanded: Bool = false) {
        self.id = UUID()
        self.name = name
        self.fullPath = fullPath
        self.children = children
        self.messages = messages
        self.isExpanded = isExpanded
    }

    static func == (lhs: TopicNode, rhs: TopicNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable
final class TopicTree {
    private(set) var root: TopicNode
    private(set) var hasMessages: Bool = false
    var treeVersion: Int = 0
    @ObservationIgnored private var nodeCache: [String: TopicNode] = [:]
    @ObservationIgnored private var _activeNodeCount: Int = 0
    var activeNodeCount: Int { _activeNodeCount }
    private let maxNodes = 10000

    init() {
        self.root = TopicNode(name: "", fullPath: "")
    }

    func addMessage(_ message: MQTTMessage) {
        if !hasMessages { hasMessages = true }
        let parts = message.topic.split(separator: "/").map(String.init)
        var currentPath = ""
        var currentNode = root

        for (index, part) in parts.enumerated() {
            currentPath = currentPath.isEmpty ? part : "\(currentPath)/\(part)"

            if let existingNode = nodeCache[currentPath] {
                currentNode = existingNode
            } else {
                let newNode = TopicNode(name: part, fullPath: currentPath)
                currentNode.children.append(newNode)
                currentNode.children.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                nodeCache[currentPath] = newNode
                currentNode = newNode
            }

            if index == parts.count - 1 {
                currentNode.messages.append(message)
            }
        }

        // Increment cachedTotalCount on each ancestor + leaf
        incrementAncestorCounts(for: message.topic, by: 1)

        if nodeCache.count > maxNodes {
            evictEmptyNodes()
        }
    }

    func addMessages(_ batch: [MQTTMessage], incrementVersion: Bool = true) {
        if !hasMessages && !batch.isEmpty { hasMessages = true }
        var parentsNeedingSort: [ObjectIdentifier: TopicNode] = [:]
        var topicIncrements: [String: Int] = [:]

        for message in batch {
            let parts = message.topic.split(separator: "/").map(String.init)
            var currentPath = ""
            var currentNode = root

            for (index, part) in parts.enumerated() {
                currentPath = currentPath.isEmpty ? part : "\(currentPath)/\(part)"

                if let existingNode = nodeCache[currentPath] {
                    currentNode = existingNode
                } else {
                    let newNode = TopicNode(name: part, fullPath: currentPath)
                    currentNode.children.append(newNode)
                    parentsNeedingSort[ObjectIdentifier(currentNode)] = currentNode
                    nodeCache[currentPath] = newNode
                    currentNode = newNode
                }

                if index == parts.count - 1 {
                    currentNode.messages.append(message)
                }
            }

            topicIncrements[message.topic, default: 0] += 1
        }

        // Deferred sort: sort each affected parent once
        for (_, node) in parentsNeedingSort {
            node.children.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        // Batch-update cachedTotalCount for all affected topics
        for (topic, count) in topicIncrements {
            incrementAncestorCounts(for: topic, by: count)
        }

        if nodeCache.count > maxNodes {
            evictEmptyNodes()
        }

        if incrementVersion {
            treeVersion += 1
        }
    }

    private func evictEmptyNodes() {
        let emptyPaths = nodeCache.keys.filter { path in
            guard let node = nodeCache[path] else { return false }
            return node.messages.isEmpty && node.children.isEmpty
        }

        for path in emptyPaths {
            guard let node = nodeCache[path] else { continue }

            if let parent = parentPath(for: path) {
                nodeCache[parent]?.children.removeAll { $0.id == node.id }
            } else {
                root.children.removeAll { $0.id == node.id }
            }
            nodeCache.removeValue(forKey: path)

            if nodeCache.count <= maxNodes / 2 {
                break
            }
        }
    }

    func clear() {
        root = TopicNode(name: "", fullPath: "")
        nodeCache.removeAll()
        _activeNodeCount = 0
        hasMessages = false
        treeVersion += 1
    }

    func findNode(at path: String) -> TopicNode? {
        nodeCache[path]
    }

    func allNodes() -> [TopicNode] {
        Array(nodeCache.values)
    }

    func ensureTopic(_ path: String) {
        let parts = path.split(separator: "/").map(String.init)
        var currentPath = ""
        var currentNode = root

        for part in parts {
            currentPath = currentPath.isEmpty ? part : "\(currentPath)/\(part)"

            if let existingNode = nodeCache[currentPath] {
                currentNode = existingNode
            } else {
                let newNode = TopicNode(name: part, fullPath: currentPath)
                currentNode.children.append(newNode)
                currentNode.children.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                nodeCache[currentPath] = newNode
                currentNode = newNode
            }
        }
    }

    func removeTopic(_ path: String) {
        guard let node = nodeCache[path] else { return }

        // Subtract this subtree's count from ancestors before removing
        let subtreeCount = node.cachedTotalCount
        if subtreeCount > 0 {
            decrementAncestorCounts(for: path, by: subtreeCount)
        }

        // Remove from parent's children
        if let parentPath = parentPath(for: path) {
            if let parentNode = nodeCache[parentPath] {
                parentNode.children.removeAll { $0.id == node.id }
            }
        } else {
            // It's a top-level node
            root.children.removeAll { $0.id == node.id }
        }

        // Remove this node and all its children from cache
        removeFromCache(node)
        treeVersion += 1
    }

    private func parentPath(for path: String) -> String? {
        let parts = path.split(separator: "/")
        guard parts.count > 1 else { return nil }
        return parts.dropLast().joined(separator: "/")
    }

    private func removeFromCache(_ node: TopicNode) {
        nodeCache.removeValue(forKey: node.fullPath)
        for child in node.children {
            removeFromCache(child)
        }
    }

    private func incrementAncestorCounts(for topicPath: String, by count: Int) {
        root.cachedTotalCount += count
        let parts = topicPath.split(separator: "/")
        var currentPath = ""
        for part in parts {
            currentPath = currentPath.isEmpty ? String(part) : "\(currentPath)/\(part)"
            if let node = nodeCache[currentPath] {
                let wasZero = node.cachedTotalCount == 0
                node.cachedTotalCount += count
                if wasZero && node.cachedTotalCount > 0 {
                    _activeNodeCount += 1
                }
            }
        }
    }

    func trimMessages(retaining survivingIds: Set<UUID>) {
        for node in nodeCache.values {
            node.messages.removeAll { !survivingIds.contains($0.id) }
        }
        recomputeCounts()
        treeVersion += 1
    }

    private func recomputeCounts() {
        root.cachedTotalCount = 0
        _activeNodeCount = 0
        for node in nodeCache.values {
            node.cachedTotalCount = 0
        }
        for node in nodeCache.values where !node.messages.isEmpty {
            incrementAncestorCounts(for: node.fullPath, by: node.messages.count)
        }
    }

    private func decrementAncestorCounts(for topicPath: String, by count: Int) {
        root.cachedTotalCount -= count
        let parts = topicPath.split(separator: "/")
        var currentPath = ""
        for part in parts {
            currentPath = currentPath.isEmpty ? String(part) : "\(currentPath)/\(part)"
            if let node = nodeCache[currentPath] {
                let wasPositive = node.cachedTotalCount > 0
                node.cachedTotalCount -= count
                if wasPositive && node.cachedTotalCount <= 0 {
                    _activeNodeCount -= 1
                }
            }
        }
    }
}
