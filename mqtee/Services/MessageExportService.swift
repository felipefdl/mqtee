import Foundation

enum MessageExportFormat: String, CaseIterable {
    case markdown = "Markdown"
    case json = "JSON"
    case csv = "CSV"
}

struct MessageExportService {

    // MARK: - Single Message

    static func formatMessage(_ message: MQTTMessage, as format: MessageExportFormat) -> String {
        switch format {
        case .markdown: return formatAsMarkdown(message)
        case .json: return formatAsJSON(message)
        case .csv: return formatMessagesAsCSV([message])
        }
    }

    static func formatAsMarkdown(_ message: MQTTMessage) -> String {
        let qosLabel = "\(message.qos.rawValue) (\(message.qos.displayName.replacingOccurrences(of: "QoS \(message.qos.rawValue) - ", with: "")))"
        let retained = message.retained ? "Yes" : "No"
        let timestamp = isoFormatter.string(from: message.timestamp)
        let size = ByteCountFormatter.string(fromByteCount: Int64(message.payload.count), countStyle: .memory)
        let contentType = message.contentType.rawValue

        let direction = message.sentByMe ? "Sent" : "Received"

        var result = """
            Topic: \(message.topic)
            Direction: \(direction)
            QoS: \(qosLabel)
            Retained: \(retained)
            Timestamp: \(timestamp)
            Size: \(size)
            Content Type: \(contentType)
            """

        if message.hasMQTT5Properties {
            result += "\n"
            if let ct = message.mqttContentType {
                result += "\nMQTT Content Type: \(ct)"
            }
            if let rt = message.responseTopic {
                result += "\nResponse Topic: \(rt)"
            }
            if let data = message.correlationData {
                let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                result += "\nCorrelation Data: \(hex)"
            }
            if let indicator = message.payloadFormatIndicator {
                result += "\nPayload Format: \(indicator == 1 ? "UTF-8" : "Bytes")"
            }
            if let expiry = message.messageExpiryInterval {
                result += "\nMessage Expiry: \(expiry)s"
            }
            for prop in message.userProperties {
                result += "\nUser Property: \(prop.key) = \(prop.value)"
            }
        }

        let payloadString = message.payloadString
        if !payloadString.isEmpty {
            let fence = message.contentType == .json ? "```json" : "```"
            let formattedPayload = message.contentType == .json ? message.formattedPayload : payloadString
            result += "\n\n\(fence)\n\(formattedPayload)\n```"
        }

        return result
    }

    static func formatAsJSON(_ message: MQTTMessage) -> String {
        let dict = messageToDictionary(message)
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    // MARK: - Multiple Messages

    static func formatMessages(_ messages: [MQTTMessage], as format: MessageExportFormat) -> String {
        switch format {
        case .markdown:
            return messages.map { formatAsMarkdown($0) }.joined(separator: "\n\n---\n\n")
        case .json:
            return formatMessagesAsJSON(messages)
        case .csv:
            return formatMessagesAsCSV(messages)
        }
    }

    static func formatMessagesAsJSON(_ messages: [MQTTMessage]) -> String {
        let dicts = messages.map { messageToDictionary($0) }
        guard let data = try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    static func formatMessagesAsCSV(_ messages: [MQTTMessage]) -> String {
        var lines = ["topic,qos,retained,sentByMe,timestamp,size,contentType,payload"]
        for message in messages {
            let row = [
                csvEscape(message.topic),
                "\(message.qos.rawValue)",
                message.retained ? "true" : "false",
                message.sentByMe ? "true" : "false",
                csvEscape(isoFormatter.string(from: message.timestamp)),
                "\(message.payload.count)",
                csvEscape(message.contentType.rawValue),
                csvEscape(message.payloadString),
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Clipboard

    static func copyToClipboard(_ string: String) {
        PlatformClipboard.copy(string)
    }

    // MARK: - Private Helpers

    private static func messageToDictionary(_ message: MQTTMessage) -> [String: Any] {
        var dict: [String: Any] = [
            "topic": message.topic,
            "qos": message.qos.rawValue,
            "retained": message.retained,
            "sentByMe": message.sentByMe,
            "timestamp": isoFormatter.string(from: message.timestamp),
            "size": message.payload.count,
            "contentType": message.contentType.rawValue,
        ]

        if let string = String(data: message.payload, encoding: .utf8) {
            if message.isJSON,
               let jsonObject = try? JSONSerialization.jsonObject(with: message.payload) {
                dict["payload"] = jsonObject
            } else {
                dict["payload"] = string
            }
        } else {
            dict["payload"] = message.payload.base64EncodedString()
        }

        if message.hasMQTT5Properties {
            if let ct = message.mqttContentType {
                dict["mqttContentType"] = ct
            }
            if let rt = message.responseTopic {
                dict["responseTopic"] = rt
            }
            if let data = message.correlationData {
                dict["correlationData"] = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            }
            if let indicator = message.payloadFormatIndicator {
                dict["payloadFormatIndicator"] = indicator
            }
            if let expiry = message.messageExpiryInterval {
                dict["messageExpiryInterval"] = expiry
            }
            if !message.userProperties.isEmpty {
                dict["userProperties"] = message.userProperties.map { ["key": $0.key, "value": $0.value] }
            }
        }

        return dict
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
