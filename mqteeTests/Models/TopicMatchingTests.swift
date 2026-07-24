import Testing
import Foundation
@testable import MQTee

@Suite("MQTT Topic Matching")
struct TopicMatchingTests {

    // MARK: - Exact match

    @Test("Exact match returns true")
    func exactMatch() {
        #expect(mqttTopicMatchesPattern(topic: "a/b/c", pattern: "a/b/c"))
    }

    @Test("Single segment exact match")
    func singleSegmentExactMatch() {
        #expect(mqttTopicMatchesPattern(topic: "test", pattern: "test"))
    }

    @Test("Non-matching returns false")
    func nonMatching() {
        #expect(!mqttTopicMatchesPattern(topic: "a/b/c", pattern: "a/b/d"))
    }

    @Test("Different depth returns false")
    func differentDepth() {
        #expect(!mqttTopicMatchesPattern(topic: "a/b", pattern: "a/b/c"))
        #expect(!mqttTopicMatchesPattern(topic: "a/b/c", pattern: "a/b"))
    }

    // MARK: - Multi-level wildcard (#)

    @Test("# matches everything")
    func hashMatchesEverything() {
        #expect(mqttTopicMatchesPattern(topic: "a/b/c", pattern: "#"))
        #expect(mqttTopicMatchesPattern(topic: "single", pattern: "#"))
        #expect(mqttTopicMatchesPattern(topic: "a/b/c/d/e/f", pattern: "#"))
    }

    @Test("Trailing # matches all descendants")
    func trailingHash() {
        #expect(mqttTopicMatchesPattern(topic: "sensor/temp", pattern: "sensor/#"))
        #expect(mqttTopicMatchesPattern(topic: "sensor/temp/room1", pattern: "sensor/#"))
        #expect(mqttTopicMatchesPattern(topic: "sensor/humidity", pattern: "sensor/#"))
    }

    @Test("# at deeper level matches remaining")
    func hashAtDeeperLevel() {
        #expect(mqttTopicMatchesPattern(topic: "a/b/c/d", pattern: "a/b/#"))
        #expect(mqttTopicMatchesPattern(topic: "a/b/c", pattern: "a/b/#"))
    }

    @Test("# does not match parent level")
    func hashDoesNotMatchParent() {
        #expect(!mqttTopicMatchesPattern(topic: "other/temp", pattern: "sensor/#"))
    }

    // MARK: - Single-level wildcard (+)

    @Test("+ matches single level")
    func plusMatchesSingleLevel() {
        #expect(mqttTopicMatchesPattern(topic: "sensor/temp", pattern: "sensor/+"))
        #expect(mqttTopicMatchesPattern(topic: "sensor/humidity", pattern: "sensor/+"))
    }

    @Test("+ at first level")
    func plusAtFirstLevel() {
        #expect(mqttTopicMatchesPattern(topic: "sensor/temp", pattern: "+/temp"))
        #expect(mqttTopicMatchesPattern(topic: "device/temp", pattern: "+/temp"))
    }

    @Test("+ at middle level")
    func plusAtMiddleLevel() {
        #expect(mqttTopicMatchesPattern(topic: "a/b/c", pattern: "a/+/c"))
        #expect(mqttTopicMatchesPattern(topic: "a/x/c", pattern: "a/+/c"))
    }

    @Test("+ does not match multiple levels")
    func plusDoesNotMatchMultipleLevels() {
        #expect(!mqttTopicMatchesPattern(topic: "a/b/c", pattern: "+"))
        #expect(!mqttTopicMatchesPattern(topic: "a/b/c", pattern: "a/+"))
    }

    @Test("Multiple + wildcards")
    func multiplePlusWildcards() {
        #expect(mqttTopicMatchesPattern(topic: "a/b/c", pattern: "+/+/c"))
        #expect(mqttTopicMatchesPattern(topic: "x/y/z", pattern: "+/+/z"))
        #expect(mqttTopicMatchesPattern(topic: "a/b/c", pattern: "+/+/+"))
    }

    // MARK: - Combined wildcards

    @Test("+ and # combined")
    func plusAndHashCombined() {
        #expect(mqttTopicMatchesPattern(topic: "a/b/c/d", pattern: "+/b/#"))
        #expect(mqttTopicMatchesPattern(topic: "x/b/c/d/e", pattern: "+/b/#"))
    }

    @Test("Multiple + before #")
    func multiplePlusBeforeHash() {
        #expect(mqttTopicMatchesPattern(topic: "a/b/c/d/e", pattern: "+/+/#"))
    }

    // MARK: - Edge cases

    @Test("Empty topic segments preserved")
    func emptyTopicSegments() {
        // MQTT allows empty segments like "a//b"
        #expect(mqttTopicMatchesPattern(topic: "a//b", pattern: "a//b"))
        #expect(mqttTopicMatchesPattern(topic: "a//b", pattern: "a/+/b"))
    }

    @Test("Single segment with +")
    func singleSegmentWithPlus() {
        #expect(mqttTopicMatchesPattern(topic: "test", pattern: "+"))
    }

    @Test("Pattern longer than topic returns false")
    func patternLongerThanTopic() {
        #expect(!mqttTopicMatchesPattern(topic: "a", pattern: "a/b"))
    }

    @Test("Topic longer than pattern returns false")
    func topicLongerThanPattern() {
        #expect(!mqttTopicMatchesPattern(topic: "a/b/c", pattern: "a/b"))
    }

    @Test("Case sensitivity preserved")
    func caseSensitivity() {
        #expect(!mqttTopicMatchesPattern(topic: "Sensor/Temp", pattern: "sensor/temp"))
        #expect(mqttTopicMatchesPattern(topic: "Sensor/Temp", pattern: "Sensor/Temp"))
    }

    @Test("Special characters in topics")
    func specialCharacters() {
        #expect(mqttTopicMatchesPattern(topic: "$SYS/broker/uptime", pattern: "$SYS/broker/uptime"))
        #expect(mqttTopicMatchesPattern(topic: "$SYS/broker/uptime", pattern: "$SYS/#"))
    }
}
