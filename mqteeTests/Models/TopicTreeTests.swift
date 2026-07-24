import Testing
import Foundation
@testable import MQTee

@Suite("TopicTree")
struct TopicTreeTests {

    @Test("addMessage creates 3-level hierarchy")
    func addMessageCreatesHierarchy() {
        let tree = TopicTree()
        let msg = MQTTMessage(topic: "a/b/c", payloadString: "data")
        tree.addMessage(msg)

        #expect(tree.root.children.count == 1)
        #expect(tree.root.children.first?.name == "a")

        let nodeA = tree.root.children.first!
        #expect(nodeA.children.count == 1)
        #expect(nodeA.children.first?.name == "b")

        let nodeB = nodeA.children.first!
        #expect(nodeB.children.count == 1)
        #expect(nodeB.children.first?.name == "c")
    }

    @Test("addMessage twice with same topic appends both messages")
    func addMessageAppendsTwice() {
        let tree = TopicTree()
        let msg1 = MQTTMessage(topic: "sensor/temp", payloadString: "22")
        let msg2 = MQTTMessage(topic: "sensor/temp", payloadString: "23")
        tree.addMessage(msg1)
        tree.addMessage(msg2)

        let node = tree.findNode(at: "sensor/temp")
        #expect(node != nil)
        #expect(node?.messages.count == 2)
    }

    @Test("Children are sorted alphabetically case-insensitive")
    func childrenSortedAlphabetically() {
        let tree = TopicTree()
        tree.addMessage(MQTTMessage(topic: "z/data", payloadString: "1"))
        tree.addMessage(MQTTMessage(topic: "A/data", payloadString: "2"))
        tree.addMessage(MQTTMessage(topic: "m/data", payloadString: "3"))

        let names = tree.root.children.map(\.name)
        #expect(names == ["A", "m", "z"])
    }

    @Test("findNode returns correct node after insertion")
    func findNodeReturnsCorrectNode() {
        let tree = TopicTree()
        tree.addMessage(MQTTMessage(topic: "a/b", payloadString: "data"))

        let node = tree.findNode(at: "a/b")
        #expect(node != nil)
        #expect(node?.fullPath == "a/b")
        #expect(node?.name == "b")
    }

    @Test("findNode returns nil for nonexistent path")
    func findNodeReturnsNilForNonexistent() {
        let tree = TopicTree()
        tree.addMessage(MQTTMessage(topic: "a/b", payloadString: "data"))

        #expect(tree.findNode(at: "nonexistent") == nil)
        #expect(tree.findNode(at: "a/c") == nil)
    }

    @Test("totalMessageCount aggregates recursively")
    func totalMessageCountAggregates() {
        let tree = TopicTree()
        tree.addMessage(MQTTMessage(topic: "a/b", payloadString: "1"))
        tree.addMessage(MQTTMessage(topic: "a/c", payloadString: "2"))
        tree.addMessage(MQTTMessage(topic: "a/c", payloadString: "3"))

        let nodeA = tree.findNode(at: "a")!
        #expect(nodeA.totalMessageCount == 3)
    }

    @Test("clear empties root children and cache")
    func clearEmptiesTree() {
        let tree = TopicTree()
        tree.addMessage(MQTTMessage(topic: "a/b/c", payloadString: "data"))
        #expect(tree.root.children.count == 1)

        tree.clear()
        #expect(tree.root.children.isEmpty)
        #expect(tree.findNode(at: "a") == nil)
    }

    @Test("removeTopic removes node and descendants from cache")
    func removeTopicRemovesNodeAndDescendants() {
        let tree = TopicTree()
        tree.addMessage(MQTTMessage(topic: "a/b/c", payloadString: "data"))
        tree.addMessage(MQTTMessage(topic: "a/d", payloadString: "other"))

        tree.removeTopic("a/b")

        #expect(tree.findNode(at: "a/b") == nil)
        #expect(tree.findNode(at: "a/b/c") == nil)
        #expect(tree.findNode(at: "a/d") != nil)

        let nodeA = tree.findNode(at: "a")!
        #expect(nodeA.children.count == 1)
        #expect(nodeA.children.first?.name == "d")
    }

    @Test("ensureTopic creates nodes without messages")
    func ensureTopicCreatesNodesWithoutMessages() {
        let tree = TopicTree()
        tree.ensureTopic("x/y")

        let nodeX = tree.findNode(at: "x")
        #expect(nodeX != nil)
        #expect(nodeX?.messages.isEmpty == true)

        let nodeY = tree.findNode(at: "x/y")
        #expect(nodeY != nil)
        #expect(nodeY?.messages.isEmpty == true)
    }

    @Test("TopicNode messageCount returns direct message count")
    func nodeMessageCount() {
        let node = TopicNode(name: "test", fullPath: "test")
        #expect(node.messageCount == 0)

        node.messages.append(MQTTMessage(topic: "test", payloadString: "1"))
        #expect(node.messageCount == 1)
    }

    @Test("TopicNode hasChildren reflects children array")
    func nodeHasChildren() {
        let node = TopicNode(name: "parent", fullPath: "parent")
        #expect(node.hasChildren == false)

        node.children.append(TopicNode(name: "child", fullPath: "parent/child"))
        #expect(node.hasChildren == true)
    }

    @Test("TopicNode latestMessage returns last message")
    func nodeLatestMessage() {
        let node = TopicNode(name: "t", fullPath: "t")
        #expect(node.latestMessage == nil)

        let msg1 = MQTTMessage(topic: "t", payloadString: "first")
        let msg2 = MQTTMessage(topic: "t", payloadString: "second")
        node.messages.append(msg1)
        node.messages.append(msg2)

        #expect(node.latestMessage?.id == msg2.id)
    }
}
