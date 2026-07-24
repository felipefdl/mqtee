import Foundation
@testable import MQTee

enum BenchmarkHelpers {

    // MARK: - Topic Generation

    /// Generates realistic MQTT topic paths.
    /// - Parameters:
    ///   - count: Number of unique topics to generate.
    ///   - depth: Maximum depth of topic hierarchy (number of `/`-separated levels).
    ///   - breadth: Maximum number of distinct names at each level.
    /// - Returns: Array of topic strings like `"home/floor1/room0/temperature"`.
    static func generateTopics(count: Int, depth: Int = 4, breadth: Int = 10) -> [String] {
        let segments = [
            "home", "office", "factory", "warehouse", "lab",
            "floor0", "floor1", "floor2", "floor3", "floor4",
            "room0", "room1", "room2", "room3", "room4",
            "temperature", "humidity", "pressure", "power", "status",
            "sensor0", "sensor1", "sensor2", "sensor3", "sensor4",
            "device0", "device1", "device2", "device3", "device4",
        ]

        var topics: [String] = []
        topics.reserveCapacity(count)

        for i in 0..<count {
            let levelCount = (i % depth) + 1
            var parts: [String] = []
            for level in 0..<levelCount {
                let segmentIndex = (i + level * 7) % min(breadth, segments.count)
                parts.append(segments[segmentIndex])
            }
            topics.append(parts.joined(separator: "/"))
        }

        return topics
    }

    // MARK: - Message Factories

    /// Creates a single MQTTMessage with the given topic and payload size.
    static func makeMessage(topic: String, payloadSize: Int = 64) -> MQTTMessage {
        let payload = makeJSONString(approximateBytes: payloadSize)
        return MQTTMessage(topic: topic, payloadString: payload)
    }

    /// Creates a batch of messages distributed across the given number of unique topics.
    /// - Parameters:
    ///   - count: Total number of messages.
    ///   - uniqueTopics: Number of distinct topics to rotate through.
    ///   - withV5: If true, populates MQTT 5 properties on every message.
    static func makeBatchMessages(count: Int, uniqueTopics: Int = 50, withV5: Bool = false) -> [MQTTMessage] {
        let topics = generateTopics(count: uniqueTopics)
        var messages: [MQTTMessage] = []
        messages.reserveCapacity(count)

        for i in 0..<count {
            let topic = topics[i % topics.count]
            let payload = "{\"value\":\(i),\"ts\":\(Date().timeIntervalSince1970)}"

            if withV5 {
                messages.append(MQTTMessage(
                    topic: topic,
                    payloadString: payload,
                    mqttContentType: "application/json",
                    responseTopic: "reply/\(topic)",
                    correlationData: Data([0xDE, 0xAD, UInt8(i & 0xFF)]),
                    userProperties: [
                        MQTTUserProperty(key: "source", value: "benchmark"),
                        MQTTUserProperty(key: "index", value: "\(i)"),
                    ],
                    payloadFormatIndicator: 1,
                    messageExpiryInterval: 3600
                ))
            } else {
                messages.append(MQTTMessage(topic: topic, payloadString: payload))
            }
        }

        return messages
    }

    // MARK: - Payload Generators

    /// Generates a valid JSON string of approximately the given byte size.
    static func makeJSONString(approximateBytes: Int) -> String {
        if approximateBytes <= 20 {
            return "{\"v\":1}"
        }

        var parts: [String] = ["{"]
        var currentSize = 2 // { and }
        var fieldIndex = 0

        while currentSize < approximateBytes {
            let key = "field\(fieldIndex)"
            let value = String(repeating: "x", count: min(50, max(1, approximateBytes - currentSize - key.count - 6)))
            let entry = "\"\(key)\":\"\(value)\""
            let separator = fieldIndex > 0 ? "," : ""
            let addition = separator + entry

            if currentSize + addition.count + 1 > approximateBytes && fieldIndex > 0 {
                break
            }

            parts.append(addition)
            currentSize += addition.count
            fieldIndex += 1
        }

        parts.append("}")
        return parts.joined()
    }

    /// Generates non-UTF-8 binary data of the given size.
    static func makeBinaryData(size: Int) -> Data {
        var data = Data(count: size)
        for i in 0..<size {
            data[i] = UInt8((i * 173 + 137) & 0xFF)
        }
        // Ensure it is not valid UTF-8 by inserting an invalid continuation byte
        if size >= 2 {
            data[0] = 0xC0
            data[1] = 0x01 // invalid continuation
        }
        return data
    }

    /// Generates a mix of subscription patterns: exact, `+` wildcard, and `#` wildcard.
    static func makeSubscriptionPatterns(count: Int) -> [String] {
        var patterns: [String] = []
        patterns.reserveCapacity(count)

        for i in 0..<count {
            switch i % 3 {
            case 0:
                patterns.append("home/floor\(i % 5)/room\(i % 5)/temperature")
            case 1:
                patterns.append("home/+/room\(i % 5)/+")
            default:
                patterns.append("home/floor\(i % 5)/#")
            }
        }

        return patterns
    }

    /// Generates a valid XML string of approximately the given byte size.
    static func makeXMLString(approximateBytes: Int) -> String {
        if approximateBytes <= 30 {
            return "<root><v>1</v></root>"
        }
        let body = String(repeating: "x", count: max(1, approximateBytes - 26))
        return "<root><data>\(body)</data></root>"
    }
}
