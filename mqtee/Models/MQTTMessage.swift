import Foundation
import SwiftUI

struct MQTTUserProperty: Hashable, Codable {
    var key: String
    var value: String
}

struct MQTTMessage: Identifiable, Codable {
    let id: UUID
    let topic: String
    let payload: Data
    let qos: QoSLevel
    let retained: Bool
    let timestamp: Date
    let subscriptionId: UUID?
    let sentByMe: Bool
    let mqttContentType: String?
    let responseTopic: String?
    let correlationData: Data?
    let userProperties: [MQTTUserProperty]
    let payloadFormatIndicator: UInt8?
    let messageExpiryInterval: UInt32?

    // Pre-computed values for rendering performance
    let cachedPayloadString: String
    let cachedPayloadPreview: String
    let cachedContentType: PayloadContentType
    let formattedTime: String
    let formattedSize: String

    private enum CodingKeys: String, CodingKey {
        case id, topic, payload, qos, retained, timestamp, subscriptionId, sentByMe
        case mqttContentType, responseTopic, correlationData, userProperties
        case payloadFormatIndicator, messageExpiryInterval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        topic = try container.decode(String.self, forKey: .topic)
        payload = try container.decode(Data.self, forKey: .payload)
        qos = try container.decode(QoSLevel.self, forKey: .qos)
        retained = try container.decode(Bool.self, forKey: .retained)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        subscriptionId = try container.decodeIfPresent(UUID.self, forKey: .subscriptionId)
        sentByMe = try container.decodeIfPresent(Bool.self, forKey: .sentByMe) ?? false
        mqttContentType = try container.decodeIfPresent(String.self, forKey: .mqttContentType)
        responseTopic = try container.decodeIfPresent(String.self, forKey: .responseTopic)
        correlationData = try container.decodeIfPresent(Data.self, forKey: .correlationData)
        userProperties = try container.decodeIfPresent([MQTTUserProperty].self, forKey: .userProperties) ?? []
        payloadFormatIndicator = try container.decodeIfPresent(UInt8.self, forKey: .payloadFormatIndicator)
        messageExpiryInterval = try container.decodeIfPresent(UInt32.self, forKey: .messageExpiryInterval)
        cachedPayloadString = Self.computePayloadString(payload)
        cachedPayloadPreview = Self.computePayloadPreview(payload, payloadString: cachedPayloadString)
        cachedContentType = PayloadContentType.detect(from: payload)
        formattedTime = timestamp.formatted(date: .omitted, time: .standard)
        formattedSize = payload.count.formatted(.byteCount(style: .file))
    }

    var hasMQTT5Properties: Bool {
        mqttContentType != nil || responseTopic != nil || correlationData != nil
            || !userProperties.isEmpty || payloadFormatIndicator != nil || messageExpiryInterval != nil
    }

    var payloadString: String { cachedPayloadString }

    var payloadPreview: String { cachedPayloadPreview }

    private static func computePayloadString(_ payload: Data) -> String {
        String(data: payload, encoding: .utf8) ?? payload.base64EncodedString()
    }

    private static func computeFormattedPayload(_ payload: Data, payloadString: String) -> String {
        if let pretty = JSONPrettyPrinter.prettyPrint(payloadString) {
            return pretty
        }
        return payloadString
    }

    private static func computePayloadPreview(_ payload: Data, payloadString: String) -> String {
        let maxChars = 300
        if payload.count <= maxChars {
            return payloadString.count > maxChars ? String(payloadString.prefix(maxChars)) + "..." : payloadString
        }
        let truncated = payload.prefix(maxChars)
        if let utf8 = String(data: truncated, encoding: .utf8) {
            return utf8 + "..."
        }
        let b64 = payload.prefix(200).base64EncodedString(options: .lineLength76Characters)
        return b64 + "..."
    }

    var isJSON: Bool {
        guard let string = String(data: payload, encoding: .utf8) else { return false }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
               (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
    }

    var contentType: PayloadContentType { cachedContentType }

    var formattedPayload: String {
        Self.computeFormattedPayload(payload, payloadString: cachedPayloadString)
    }

    init(
        id: UUID = UUID(),
        topic: String,
        payload: Data,
        qos: QoSLevel = .atMostOnce,
        retained: Bool = false,
        timestamp: Date = Date(),
        subscriptionId: UUID? = nil,
        sentByMe: Bool = false,
        mqttContentType: String? = nil,
        responseTopic: String? = nil,
        correlationData: Data? = nil,
        userProperties: [MQTTUserProperty] = [],
        payloadFormatIndicator: UInt8? = nil,
        messageExpiryInterval: UInt32? = nil
    ) {
        self.id = id
        self.topic = topic
        self.payload = payload
        self.qos = qos
        self.retained = retained
        self.timestamp = timestamp
        self.subscriptionId = subscriptionId
        self.sentByMe = sentByMe
        self.mqttContentType = mqttContentType
        self.responseTopic = responseTopic
        self.correlationData = correlationData
        self.userProperties = userProperties
        self.payloadFormatIndicator = payloadFormatIndicator
        self.messageExpiryInterval = messageExpiryInterval
        self.cachedPayloadString = Self.computePayloadString(payload)
        self.cachedPayloadPreview = Self.computePayloadPreview(payload, payloadString: cachedPayloadString)
        self.cachedContentType = PayloadContentType.detect(from: payload)
        self.formattedTime = timestamp.formatted(date: .omitted, time: .standard)
        self.formattedSize = payload.count.formatted(.byteCount(style: .file))
    }

    init(
        id: UUID = UUID(),
        topic: String,
        payloadString: String,
        qos: QoSLevel = .atMostOnce,
        retained: Bool = false,
        timestamp: Date = Date(),
        subscriptionId: UUID? = nil,
        sentByMe: Bool = false,
        mqttContentType: String? = nil,
        responseTopic: String? = nil,
        correlationData: Data? = nil,
        userProperties: [MQTTUserProperty] = [],
        payloadFormatIndicator: UInt8? = nil,
        messageExpiryInterval: UInt32? = nil
    ) {
        self.id = id
        self.topic = topic
        self.payload = payloadString.data(using: .utf8) ?? Data()
        self.qos = qos
        self.retained = retained
        self.timestamp = timestamp
        self.subscriptionId = subscriptionId
        self.sentByMe = sentByMe
        self.mqttContentType = mqttContentType
        self.responseTopic = responseTopic
        self.correlationData = correlationData
        self.userProperties = userProperties
        self.payloadFormatIndicator = payloadFormatIndicator
        self.messageExpiryInterval = messageExpiryInterval
        self.cachedPayloadString = payloadString
        self.cachedPayloadPreview = Self.computePayloadPreview(payload, payloadString: payloadString)
        self.cachedContentType = PayloadContentType.detect(from: payload)
        self.formattedTime = timestamp.formatted(date: .omitted, time: .standard)
        self.formattedSize = payload.count.formatted(.byteCount(style: .file))
    }
}

extension MQTTMessage: Hashable {
    static func == (lhs: MQTTMessage, rhs: MQTTMessage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Subscription: Identifiable, Hashable, Codable {
    let id: UUID
    var topic: String
    var qos: QoSLevel
    var color: SubscriptionColor
    // MQTT 5 subscription options
    var noLocal: Bool
    var retainAsPublished: Bool
    var retainHandling: RetainHandling

    init(
        id: UUID = UUID(),
        topic: String,
        qos: QoSLevel = .atMostOnce,
        color: SubscriptionColor = .blue,
        noLocal: Bool = false,
        retainAsPublished: Bool = false,
        retainHandling: RetainHandling = .sendOnSubscribe
    ) {
        self.id = id
        self.topic = topic
        self.qos = qos
        self.color = color
        self.noLocal = noLocal
        self.retainAsPublished = retainAsPublished
        self.retainHandling = retainHandling
    }
}

enum RetainHandling: Int, CaseIterable, Hashable, Codable {
    case sendOnSubscribe = 0
    case sendOnNewSubscribe = 1
    case doNotSend = 2

    var description: String {
        switch self {
        case .sendOnSubscribe: return "Send on subscribe"
        case .sendOnNewSubscribe: return "Send if new subscription"
        case .doNotSend: return "Do not send"
        }
    }
}

enum SubscriptionColor: String, CaseIterable, Hashable, Codable {
    case blue
    case green
    case orange
    case purple
    case red
    case teal
    case pink
    case yellow

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .red: return .red
        case .teal: return .teal
        case .pink: return .pink
        case .yellow: return .yellow
        }
    }

    static func next(after colors: [SubscriptionColor]) -> SubscriptionColor {
        let usedColors = Set(colors)
        for color in SubscriptionColor.allCases {
            if !usedColors.contains(color) {
                return color
            }
        }
        return SubscriptionColor.allCases.randomElement() ?? .blue
    }
}
