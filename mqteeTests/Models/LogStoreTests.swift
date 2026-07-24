import Testing
import Foundation
@testable import MQTee

@Suite("LogStore", .serialized)
@MainActor
struct LogStoreTests {

    init() {
        LogStore.shared.clear()
    }

    @Test("log appends an entry")
    func logAppendsEntry() {
        let store = LogStore.shared
        store.log(level: .info, category: .connection, message: "Connected")

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.message == "Connected")
        #expect(store.entries.first?.level == .info)
        #expect(store.entries.first?.category == .connection)
    }

    @Test("Trimming keeps count at maxEntries")
    func trimmingKeepsMaxEntries() {
        let store = LogStore.shared
        store.maxEntries = 100

        for i in 0..<150 {
            store.log(level: .debug, category: .message, message: "msg \(i)")
        }

        #expect(store.entries.count == 100)
        #expect(store.entries.first?.message == "msg 50")
        #expect(store.entries.last?.message == "msg 149")
    }

    @Test("clear empties entries")
    func clearEmptiesEntries() {
        let store = LogStore.shared
        store.log(level: .info, category: .connection, message: "test")
        #expect(!store.entries.isEmpty)

        store.clear()
        #expect(store.entries.isEmpty)
    }

    @Test("logConnection sets category to .connection")
    func logConnectionSetsCategory() {
        let store = LogStore.shared
        store.logConnection("Connected to broker")

        #expect(store.entries.last?.category == .connection)
        #expect(store.entries.last?.level == .info)
    }

    @Test("logSubscription sets category to .subscription")
    func logSubscriptionSetsCategory() {
        let store = LogStore.shared
        store.logSubscription("Subscribed", topic: "test/topic")

        #expect(store.entries.last?.category == .subscription)
        #expect(store.entries.last?.topic == "test/topic")
    }

    @Test("logPublish sets category to .publish")
    func logPublishSetsCategory() {
        let store = LogStore.shared
        store.logPublish("Published", topic: "out/topic")

        #expect(store.entries.last?.category == .publish)
        #expect(store.entries.last?.topic == "out/topic")
    }

    @Test("logMessage sets category to .message with debug level")
    func logMessageSetsCategory() {
        let store = LogStore.shared
        store.logMessage("Received", topic: "in/topic")

        #expect(store.entries.last?.category == .message)
        #expect(store.entries.last?.level == .debug)
    }

    @Test("logError sets level to .error and category to .error")
    func logErrorSetsLevelAndCategory() {
        let store = LogStore.shared
        store.logError("Something failed", details: "Detail info")

        #expect(store.entries.last?.level == .error)
        #expect(store.entries.last?.category == .error)
        #expect(store.entries.last?.details == "Detail info")
    }
}
