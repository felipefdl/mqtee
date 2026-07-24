import Testing
import Foundation
@testable import MQTee

@Suite("MQTTMessage")
struct MQTTMessageTests {

    // MARK: - payloadString

    @Test("payloadString returns UTF-8 string for valid payload")
    func payloadStringReturnsUtf8() {
        let message = MQTTMessage(topic: "test", payloadString: "hello")
        #expect(message.payloadString == "hello")
    }

    @Test("payloadString returns base64 for non-UTF8 payload")
    func payloadStringReturnsBase64ForNonUtf8() {
        let data = Data([0xFF, 0xFE, 0x00, 0x80])
        let message = MQTTMessage(topic: "test", payload: data)
        #expect(message.payloadString == data.base64EncodedString())
    }

    // MARK: - isJSON

    @Test("isJSON returns true for JSON object")
    func isJsonTrueForObject() {
        let message = MQTTMessage(topic: "test", payloadString: #"{"a":1}"#)
        #expect(message.isJSON == true)
    }

    @Test("isJSON returns true for JSON array")
    func isJsonTrueForArray() {
        let message = MQTTMessage(topic: "test", payloadString: "[1,2,3]")
        #expect(message.isJSON == true)
    }

    @Test("isJSON returns false for plain text")
    func isJsonFalseForPlainText() {
        let message = MQTTMessage(topic: "test", payloadString: "not json")
        #expect(message.isJSON == false)
    }

    @Test("isJSON returns false for non-UTF8")
    func isJsonFalseForNonUtf8() {
        let message = MQTTMessage(topic: "test", payload: Data([0xFF, 0xFE]))
        #expect(message.isJSON == false)
    }

    // MARK: - contentType

    @Test("contentType delegates to PayloadContentType.detect")
    func contentTypeDelegates() {
        let jsonMessage = MQTTMessage(topic: "t", payloadString: #"{"a":1}"#)
        #expect(jsonMessage.contentType == .json)

        let plainMessage = MQTTMessage(topic: "t", payloadString: "hello")
        #expect(plainMessage.contentType == .plainText)
    }

    // MARK: - formattedPayload

    @Test("formattedPayload pretty-prints JSON preserving key order")
    func formattedPayloadPrettyPrintsJson() {
        let message = MQTTMessage(topic: "t", payloadString: #"{"b":2,"a":1}"#)
        let formatted = message.formattedPayload
        #expect(formatted.contains("\n"))
        let bIndex = formatted.range(of: "\"b\"")!.lowerBound
        let aIndex = formatted.range(of: "\"a\"")!.lowerBound
        #expect(bIndex < aIndex)
    }

    @Test("formattedPayload returns payloadString for non-JSON")
    func formattedPayloadFallsBackForNonJson() {
        let message = MQTTMessage(topic: "t", payloadString: "hello world")
        #expect(message.formattedPayload == "hello world")
    }

    // MARK: - Initializers

    @Test("Init with Data preserves payload bytes")
    func initWithDataPreservesPayload() {
        let data = "test data".data(using: .utf8)!
        let message = MQTTMessage(topic: "t", payload: data)
        #expect(message.payload == data)
        #expect(message.topic == "t")
    }

    @Test("Init with payloadString converts to UTF-8 Data")
    func initWithPayloadStringConvertsToData() {
        let message = MQTTMessage(topic: "t", payloadString: "hello")
        #expect(message.payload == "hello".data(using: .utf8)!)
    }

    @Test("Default values are applied correctly")
    func defaultValues() {
        let message = MQTTMessage(topic: "t", payloadString: "p")
        #expect(message.qos == .atMostOnce)
        #expect(message.retained == false)
        #expect(message.subscriptionId == nil)
    }

    @Test("Explicit values override defaults")
    func explicitValues() {
        let subId = UUID()
        let message = MQTTMessage(
            topic: "t",
            payloadString: "p",
            qos: .exactlyOnce,
            retained: true,
            subscriptionId: subId
        )
        #expect(message.qos == .exactlyOnce)
        #expect(message.retained == true)
        #expect(message.subscriptionId == subId)
    }

    // MARK: - sentByMe

    @Test("sentByMe defaults to false")
    func sentByMeDefaultsFalse() {
        let message = MQTTMessage(topic: "test", payloadString: "hello")
        #expect(message.sentByMe == false)
    }

    @Test("sentByMe can be set to true")
    func sentByMeCanBeSetTrue() {
        let message = MQTTMessage(topic: "test", payloadString: "hello", sentByMe: true)
        #expect(message.sentByMe == true)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = MQTTMessage(
            topic: "sensor/temp",
            payloadString: #"{"temp":22.5}"#,
            qos: .atLeastOnce,
            retained: true,
            subscriptionId: UUID()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MQTTMessage.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.topic == original.topic)
        #expect(decoded.payload == original.payload)
        #expect(decoded.qos == original.qos)
        #expect(decoded.retained == original.retained)
        #expect(decoded.subscriptionId == original.subscriptionId)
        #expect(decoded.sentByMe == original.sentByMe)
    }

    @Test("Codable round-trip preserves sentByMe true")
    func codableRoundTripSentByMe() throws {
        let original = MQTTMessage(
            topic: "test/sent",
            payloadString: "hello",
            sentByMe: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MQTTMessage.self, from: data)

        #expect(decoded.sentByMe == true)
    }

    @Test("Decoding old JSON without sentByMe key defaults to false")
    func decodingOldJsonDefaultsSentByMeFalse() throws {
        let json = """
            {
                "id": "00000000-0000-0000-0000-000000000001",
                "topic": "test",
                "payload": "\("aGVsbG8=".data(using: .utf8)!.base64EncodedString())",
                "qos": 0,
                "retained": false,
                "timestamp": 0
            }
            """
        // Build JSON that matches the Codable structure without sentByMe
        let original = MQTTMessage(topic: "test", payloadString: "hello")
        var encoded = try JSONEncoder().encode(original)
        // Decode, remove sentByMe, re-encode
        var dict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        dict.removeValue(forKey: "sentByMe")
        encoded = try JSONSerialization.data(withJSONObject: dict)

        let decoded = try JSONDecoder().decode(MQTTMessage.self, from: encoded)
        #expect(decoded.sentByMe == false)
    }
}
