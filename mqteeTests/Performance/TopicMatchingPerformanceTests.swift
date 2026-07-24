import XCTest
@testable import MQTee

final class TopicMatchingPerformanceTests: XCTestCase {

    // MARK: - Individual pattern types

    func testExactMatch_10000() {
        let topic = "home/floor1/room3/temperature"
        let pattern = "home/floor1/room3/temperature"

        measure {
            for _ in 0..<10_000 {
                _ = mqttTopicMatchesPattern(topic: topic, pattern: pattern)
            }
        }
    }

    func testWildcardPlus_10000() {
        let topic = "home/floor1/room3/temperature"
        let pattern = "home/+/room3/+"

        measure {
            for _ in 0..<10_000 {
                _ = mqttTopicMatchesPattern(topic: topic, pattern: pattern)
            }
        }
    }

    func testWildcardHash_10000() {
        let topic = "home/floor1/room3/temperature"
        let pattern = "home/floor1/#"

        measure {
            for _ in 0..<10_000 {
                _ = mqttTopicMatchesPattern(topic: topic, pattern: pattern)
            }
        }
    }

    func testNoMatch_10000() {
        let topic = "home/floor1/room3/temperature"
        let pattern = "office/floor2/room1/humidity"

        measure {
            for _ in 0..<10_000 {
                _ = mqttTopicMatchesPattern(topic: topic, pattern: pattern)
            }
        }
    }

    // MARK: - Batch filtering (simulates receiveMessages hot path)

    func testBatchFilter_1000msgs_10subs() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 1000, uniqueTopics: 50)
        let patterns = BenchmarkHelpers.makeSubscriptionPatterns(count: 10)

        measure {
            var matchCount = 0
            for message in messages {
                for pattern in patterns {
                    if mqttTopicMatchesPattern(topic: message.topic, pattern: pattern) {
                        matchCount += 1
                    }
                }
            }
            _ = matchCount
        }
    }

    func testBatchFilter_5000msgs_20subs() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 5000, uniqueTopics: 100)
        let patterns = BenchmarkHelpers.makeSubscriptionPatterns(count: 20)

        measure {
            var matchCount = 0
            for message in messages {
                for pattern in patterns {
                    if mqttTopicMatchesPattern(topic: message.topic, pattern: pattern) {
                        matchCount += 1
                    }
                }
            }
            _ = matchCount
        }
    }
}
