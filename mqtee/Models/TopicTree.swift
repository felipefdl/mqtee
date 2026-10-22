import Foundation

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

    /// Splits a topic into levels, keeping empty ones so node paths equal the exact topic prefixes.
    private static func levels(of topic: String) -> [(name: String, path: String)] {
        guard !topic.isEmpty else { return [] }
        var result: [(name: String, path: String)] = []
        var path = ""
        for (index, substring) in topic.split(separator: "/", omittingEmptySubsequences: false).enumerated() {
            let name = String(substring)
            path = index == 0 ? name : "\(path)/\(name)"
            result.append((name: name, path: path))
        }
        return result
    }

    func addMessage(_ message: MQTTMessage) {
        if !hasMessages { hasMessages = true }
        var currentNode = root
        let levels = Self.levels(of: message.topic)

        for (index, level) in levels.enumerated() {
            let part = level.name
            let currentPath = level.path

            if let existingNode = nodeCache[currentPath] {
                currentNode = existingNode
            } else {
                let newNode = TopicNode(name: part, fullPath: currentPath)
                currentNode.children.append(newNode)
                currentNode.children.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                nodeCache[currentPath] = newNode
                currentNode = newNode
            }

            if index == levels.count - 1 {
                currentNode.messages.append(message)
            }
        }

        // Increment retained and received counts on each ancestor + leaf
        incrementAncestorCounts(for: message.topic, by: 1, received: true)

        if nodeCache.count > maxNodes {
            evictEmptyNodes()
        }
    }

    func addMessages(_ batch: [MQTTMessage], incrementVersion: Bool = true) {
        if !hasMessages && !batch.isEmpty { hasMessages = true }
        var parentsNeedingSort: [ObjectIdentifier: TopicNode] = [:]
        var topicIncrements: [String: Int] = [:]

        for message in batch {
            var currentNode = root
            let levels = Self.levels(of: message.topic)

            for (index, level) in levels.enumerated() {
                let part = level.name
                let currentPath = level.path

                if let existingNode = nodeCache[currentPath] {
                    currentNode = existingNode
                } else {
                    let newNode = TopicNode(name: part, fullPath: currentPath)
                    currentNode.children.append(newNode)
                    parentsNeedingSort[ObjectIdentifier(currentNode)] = currentNode
                    nodeCache[currentPath] = newNode
                    currentNode = newNode
                }

                if index == levels.count - 1 {
                    currentNode.messages.append(message)
                }
            }

            topicIncrements[message.topic, default: 0] += 1
        }

        // Deferred sort: sort each affected parent once
        for (_, node) in parentsNeedingSort {
            node.children.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        // Batch-update retained and received counts for all affected topics
        for (topic, count) in topicIncrements {
            incrementAncestorCounts(for: topic, by: count, received: true)
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
        var currentNode = root

        for level in Self.levels(of: path) {
            let part = level.name
            let currentPath = level.path

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
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return nil }
        return parts.dropLast().joined(separator: "/")
    }

    private func removeFromCache(_ node: TopicNode) {
        nodeCache.removeValue(forKey: node.fullPath)
        for child in node.children {
            removeFromCache(child)
        }
    }

    /// `received` is set only when messages arrive, so the monotonic received counters are not
    /// re-added when retained counts are rebuilt after trimming.
    private func incrementAncestorCounts(for topicPath: String, by count: Int, received: Bool = false) {
        root.cachedTotalCount += count
        if received { root.receivedTotalCount += count }
        let levels = Self.levels(of: topicPath)
        for (index, level) in levels.enumerated() {
            if let node = nodeCache[level.path] {
                let wasZero = node.cachedTotalCount == 0
                node.cachedTotalCount += count
                if wasZero && node.cachedTotalCount > 0 {
                    _activeNodeCount += 1
                }
                if received {
                    node.receivedTotalCount += count
                    if index == levels.count - 1 { node.receivedCount += count }
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
        for level in Self.levels(of: topicPath) {
            if let node = nodeCache[level.path] {
                let wasPositive = node.cachedTotalCount > 0
                node.cachedTotalCount -= count
                if wasPositive && node.cachedTotalCount <= 0 {
                    _activeNodeCount -= 1
                }
            }
        }
    }
}
