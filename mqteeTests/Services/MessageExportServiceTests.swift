import Testing
import Foundation
@testable import MQTee

@Suite("MessageExportService")
struct MessageExportServiceTests {

    static let fixedDate = Date(timeIntervalSince1970: 1700000000)

    static func makeMessage(
        topic: String = "test/topic",
        payloadString: String = "hello",
        qos: QoSLevel = .atMostOnce,
        retained: Bool = false,
        sentByMe: Bool = false
    ) -> MQTTMessage {
        MQTTMessage(
            topic: topic,
            payloadString: payloadString,
            qos: qos,
            retained: retained,
            timestamp: fixedDate,
            sentByMe: sentByMe
        )
    }

    // MARK: - formatAsMarkdown

    @Test("Markdown uses json fence for JSON messages")
    func markdownUsesJsonFence() {
        let msg = Self.makeMessage(payloadString: #"{"temp":22}"#)
        let result = MessageExportService.formatAsMarkdown(msg)

        #expect(result.contains("```json"))
        #expect(result.contains("Topic: test/topic"))
        #expect(result.contains("QoS:"))
        #expect(result.contains("Retained: No"))
    }

    @Test("Markdown uses plain fence for non-JSON messages")
    func markdownUsesPlainFence() {
        let msg = Self.makeMessage(payloadString: "plain text")
        let result = MessageExportService.formatAsMarkdown(msg)

        #expect(!result.contains("```json"))
        #expect(result.contains("```\nplain text\n```"))
    }

    // MARK: - formatAsJSON

    @Test("JSON format round-trips with correct field values")
    func jsonFormatRoundTrips() throws {
        let msg = Self.makeMessage(
            topic: "sensor/temp",
            payloadString: "hello",
            qos: .atLeastOnce,
            retained: true
        )
        let result = MessageExportService.formatAsJSON(msg)
        let parsed = try JSONSerialization.jsonObject(with: result.data(using: .utf8)!) as! [String: Any]

        #expect(parsed["topic"] as? String == "sensor/temp")
        #expect(parsed["qos"] as? Int == 1)
        #expect(parsed["retained"] as? Bool == true)
        #expect(parsed["payload"] as? String == "hello")
    }

    @Test("JSON format embeds JSON payload as object, not string")
    func jsonFormatEmbedsJsonPayload() throws {
        let msg = Self.makeMessage(payloadString: #"{"temp":22}"#)
        let result = MessageExportService.formatAsJSON(msg)
        let parsed = try JSONSerialization.jsonObject(with: result.data(using: .utf8)!) as! [String: Any]

        #expect(parsed["payload"] is [String: Any])
        let payload = parsed["payload"] as! [String: Any]
        #expect(payload["temp"] as? Int == 22)
    }

    // MARK: - formatMessagesAsCSV

    @Test("CSV has correct header row")
    func csvHeaderRow() {
        let result = MessageExportService.formatMessagesAsCSV([])
        #expect(result == "topic,qos,retained,sentByMe,timestamp,size,contentType,payload")
    }

    @Test("CSV escapes commas in topic with double-quotes")
    func csvEscapesCommasInTopic() {
        let msg = Self.makeMessage(topic: "topic,with,commas")
        let result = MessageExportService.formatMessagesAsCSV([msg])
        let lines = result.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.count == 2)
        #expect(lines[1].hasPrefix("\"topic,with,commas\""))
    }

    @Test("CSV doubles embedded quotes")
    func csvDoublesEmbeddedQuotes() {
        let msg = Self.makeMessage(payloadString: #"say "hello""#)
        let result = MessageExportService.formatMessagesAsCSV([msg])

        #expect(result.contains(#""say ""hello""""#))
    }

    // MARK: - formatMessages

    @Test("Multiple markdown messages joined with separator")
    func multipleMarkdownJoinedWithSeparator() {
        let msg1 = Self.makeMessage(topic: "t/1", payloadString: "a")
        let msg2 = Self.makeMessage(topic: "t/2", payloadString: "b")
        let result = MessageExportService.formatMessages([msg1, msg2], as: .markdown)

        #expect(result.contains("---"))
        #expect(result.contains("Topic: t/1"))
        #expect(result.contains("Topic: t/2"))
    }

    @Test("formatMessagesAsJSON with empty array returns []")
    func emptyJsonArrayReturnsEmptyArray() {
        let result = MessageExportService.formatMessagesAsJSON([])
        #expect(result == "[\n\n]")
    }

    // MARK: - sentByMe in exports

    @Test("JSON export includes sentByMe field")
    func jsonExportIncludesSentByMe() throws {
        let msg = Self.makeMessage(sentByMe: true)
        let result = MessageExportService.formatAsJSON(msg)
        let parsed = try JSONSerialization.jsonObject(with: result.data(using: .utf8)!) as! [String: Any]

        #expect(parsed["sentByMe"] as? Bool == true)
    }

    @Test("JSON export sentByMe defaults to false")
    func jsonExportSentByMeDefaultsFalse() throws {
        let msg = Self.makeMessage()
        let result = MessageExportService.formatAsJSON(msg)
        let parsed = try JSONSerialization.jsonObject(with: result.data(using: .utf8)!) as! [String: Any]

        #expect(parsed["sentByMe"] as? Bool == false)
    }

    @Test("CSV includes sentByMe column")
    func csvIncludesSentByMeColumn() {
        let msg = Self.makeMessage(sentByMe: true)
        let result = MessageExportService.formatMessagesAsCSV([msg])
        let lines = result.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines[0].contains("sentByMe"))
        #expect(lines[1].contains("true"))
    }

    @Test("Markdown includes Direction line")
    func markdownIncludesDirection() {
        let sent = Self.makeMessage(sentByMe: true)
        let received = Self.makeMessage(sentByMe: false)

        let sentResult = MessageExportService.formatAsMarkdown(sent)
        let receivedResult = MessageExportService.formatAsMarkdown(received)

        #expect(sentResult.contains("Direction: Sent"))
        #expect(receivedResult.contains("Direction: Received"))
    }
}
