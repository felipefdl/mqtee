import Testing
import Foundation
@testable import MQTee

@Suite("TopicNode pending count")
struct TopicNodePendingTests {

    /// Fills `a/b` with `count` messages and trims the tree to the newest `retained`, like retention does.
    private func tree(received count: Int, retained: Int, topic: String = "a/b") -> TopicTree {
        let tree = TopicTree()
        let messages = (0..<count).map { MQTTMessage(topic: topic, payloadString: "\($0)") }
        tree.addMessages(messages)
        tree.trimMessages(retaining: Set(messages.suffix(retained).map(\.id)))
        return tree
    }

    @Test("counts arrivals after the snapshot while retention holds the list at its cap")
    func arrivalsAtCap() throws {
        let tree = tree(received: 3, retained: 3)
        let leaf = try #require(tree.findNode(at: "a/b"))
        let parent = try #require(tree.findNode(at: "a"))
        let leafSnapshot = leaf.receivedSnapshot(includeDescendants: false)
        let parentSnapshot = parent.receivedSnapshot(includeDescendants: true)

        let newer = (0..<2).map { MQTTMessage(topic: "a/b", payloadString: "new\($0)") }
        tree.addMessages(newer)
        let retainedIds = leaf.messages.suffix(3).map(\.id)
        tree.trimMessages(retaining: Set(retainedIds))

        #expect(leaf.messageCount == 3)
        #expect(leaf.pendingCount(since: leafSnapshot, includeDescendants: false) == 2)
        #expect(parent.pendingCount(since: parentSnapshot, includeDescendants: true) == 2)
    }

    @Test("pending never exceeds the messages still retained")
    func boundedByRetained() throws {
        let leaf = try #require(tree(received: 5, retained: 3).findNode(at: "a/b"))
        #expect(leaf.pendingCount(since: 0, includeDescendants: false) == 3)
        #expect(leaf.pendingCount(since: 0, includeDescendants: true) == 3)
    }

    @Test("descendant arrivals count only when including descendants")
    func descendantsScope() throws {
        let tree = TopicTree()
        tree.addMessage(MQTTMessage(topic: "a", payloadString: "own"))
        let node = try #require(tree.findNode(at: "a"))
        let own = node.receivedSnapshot(includeDescendants: false)
        let all = node.receivedSnapshot(includeDescendants: true)

        tree.addMessage(MQTTMessage(topic: "a/child", payloadString: "x"))

        #expect(node.pendingCount(since: own, includeDescendants: false) == 0)
        #expect(node.pendingCount(since: all, includeDescendants: true) == 1)
    }
}
