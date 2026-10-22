import Testing
import Foundation
@testable import MQTee

@Suite("Session retention", .serialized)
@MainActor
struct SessionRetentionTests {

    private func session(maxMessages: Int) -> SessionStore {
        UserDefaults.standard.set(maxMessages, forKey: "maxMessagesInMemory")
        defer { UserDefaults.standard.removeObject(forKey: "maxMessagesInMemory") }
        let session = SessionStore(connection: Connection(name: "Test", host: "broker.local", port: 1883))
        session.subscriptions = [Subscription(topic: "#")]
        return session
    }

    @Test("a batch larger than the window leaves the topic tree holding exactly the retained messages")
    func batchLargerThanWindow() throws {
        let session = session(maxMessages: 3)
        session.receiveMessages((0..<2).map { MQTTMessage(topic: "a/b", payloadString: "old\($0)") })
        session.receiveMessages((0..<12).map { MQTTMessage(topic: "a/b", payloadString: "new\($0)") })

        let node = try #require(session.topicTree.findNode(at: "a/b"))
        #expect(session.messages.map(\.payloadString) == ["new9", "new10", "new11"])
        #expect(node.messages.map(\.id) == session.messages.map(\.id))
        #expect(session.topicTree.root.totalMessageCount == 3)
        #expect(node.receivedCount == 14)
    }
}
