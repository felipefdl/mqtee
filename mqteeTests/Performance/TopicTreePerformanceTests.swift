import XCTest
@testable import MQTee

@MainActor
final class TopicTreePerformanceTests: XCTestCase {

    // Each test creates a fresh tree before measuring. The tree is stored as
    // an instance property so its deallocation happens in tearDown (on the
    // main actor), avoiding @Observable dealloc crashes inside measure blocks.
    private var tree: TopicTree!

    override func setUp() {
        super.setUp()
        tree = TopicTree()
    }

    override func tearDown() {
        tree = nil
        super.tearDown()
    }

    // MARK: - addMessage (single insert)

    func testAddMessage_100UniqueTopics() {
        let topics = BenchmarkHelpers.generateTopics(count: 100)
        let messages = topics.map { BenchmarkHelpers.makeMessage(topic: $0) }

        measure {
            for message in messages {
                self.tree.addMessage(message)
            }
        }
    }

    func testAddMessage_500UniqueTopics() {
        let topics = BenchmarkHelpers.generateTopics(count: 500)
        let messages = topics.map { BenchmarkHelpers.makeMessage(topic: $0) }

        measure {
            for message in messages {
                self.tree.addMessage(message)
            }
        }
    }

    func testAddMessage_2000UniqueTopics() {
        let topics = BenchmarkHelpers.generateTopics(count: 2000, depth: 5, breadth: 20)
        let messages = topics.map { BenchmarkHelpers.makeMessage(topic: $0) }

        measure {
            for message in messages {
                self.tree.addMessage(message)
            }
        }
    }

    func testAddMessage_SameTopic_1000() {
        let messages = (0..<1000).map { i in
            MQTTMessage(topic: "home/living/temperature", payloadString: "{\"value\":\(i)}")
        }

        measure {
            for message in messages {
                self.tree.addMessage(message)
            }
        }
    }

    // MARK: - addMessages (batch insert)

    func testAddMessages_Batch1000() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 1000, uniqueTopics: 100)

        measure {
            self.tree.addMessages(messages)
        }
    }

    func testAddMessages_Batch5000() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 5000, uniqueTopics: 200)

        measure {
            self.tree.addMessages(messages)
        }
    }

    // MARK: - Deep and wide topic structures

    func testAddMessages_DeepTopics_500() {
        let topics = BenchmarkHelpers.generateTopics(count: 500, depth: 10, breadth: 5)
        let messages = topics.map { BenchmarkHelpers.makeMessage(topic: $0) }

        measure {
            self.tree.addMessages(messages)
        }
    }

    func testAddMessages_WideSiblings_500() {
        let messages = (0..<500).map { i in
            MQTTMessage(topic: "home/device\(i)", payloadString: "{\"id\":\(i)}")
        }

        measure {
            for message in messages {
                self.tree.addMessage(message)
            }
        }
    }

    // MARK: - findNode lookup

    func testFindNode_InLargeTree() {
        let topics = BenchmarkHelpers.generateTopics(count: 5000, depth: 5, breadth: 30)
        let messages = topics.map { BenchmarkHelpers.makeMessage(topic: $0) }
        tree.addMessages(messages)

        let lookupTopics = stride(from: 0, to: topics.count, by: topics.count / 100).map { topics[$0] }

        measure {
            for _ in 0..<100 {
                for topic in lookupTopics {
                    _ = self.tree.findNode(at: topic)
                }
            }
        }
    }

    // MARK: - Eviction

    func testEviction_BeyondMaxNodes() {
        let messages = (0..<12000).map { i in
            MQTTMessage(topic: "topic\(i)", payloadString: "{}")
        }

        measure {
            self.tree.addMessages(messages)
        }
    }

}
