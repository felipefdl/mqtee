//
//  PublishTab.swift
//  mqtee
//

import Foundation

enum PublishPayloadFormat: String, CaseIterable, Codable {
    case text = "Text"
    case json = "JSON"
    case xml = "XML"
    case base64 = "Base64"
    case hex = "Hex"

    var localizedName: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .json: return "curlybraces"
        case .xml: return "chevron.left.forwardslash.chevron.right"
        case .base64: return "arrow.up.arrow.down"
        case .hex: return "number"
        }
    }
}

enum PayloadFormatIndicatorOption: Int, CaseIterable, Codable, Hashable {
    case unspecified = -1
    case bytes = 0
    case utf8 = 1

    var localizedName: String {
        switch self {
        case .unspecified: return String(localized: "Unspecified", comment: "Payload format indicator unspecified")
        case .bytes: return "Bytes (0)"
        case .utf8: return "UTF-8 (1)"
        }
    }
}

struct PublishTab: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String?
    var topic: String
    var payload: String
    var payloadFormat: PublishPayloadFormat
    var qos: QoSLevel
    var retain: Bool
    var lastModified: Date
    var mqttContentType: String
    var responseTopic: String
    var correlationData: String
    var messageExpiryInterval: String
    var payloadFormatIndicator: PayloadFormatIndicatorOption
    var userProperties: [MQTTUserProperty]

    private enum CodingKeys: String, CodingKey {
        case id, name, topic, payload, payloadFormat, qos, retain, lastModified
        case mqttContentType, responseTopic, correlationData, messageExpiryInterval
        case payloadFormatIndicator, userProperties
    }

    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        if !topic.isEmpty {
            return topic
        }
        return String(localized: "Untitled", comment: "Default publish tab name")
    }

    init(
        id: UUID = UUID(),
        name: String? = nil,
        topic: String = "",
        payload: String = "",
        payloadFormat: PublishPayloadFormat = .text,
        qos: QoSLevel = .atMostOnce,
        retain: Bool = false,
        lastModified: Date = Date(),
        mqttContentType: String = "",
        responseTopic: String = "",
        correlationData: String = "",
        messageExpiryInterval: String = "",
        payloadFormatIndicator: PayloadFormatIndicatorOption = .unspecified,
        userProperties: [MQTTUserProperty] = []
    ) {
        self.id = id
        self.name = name
        self.topic = topic
        self.payload = payload
        self.payloadFormat = payloadFormat
        self.qos = qos
        self.retain = retain
        self.lastModified = lastModified
        self.mqttContentType = mqttContentType
        self.responseTopic = responseTopic
        self.correlationData = correlationData
        self.messageExpiryInterval = messageExpiryInterval
        self.payloadFormatIndicator = payloadFormatIndicator
        self.userProperties = userProperties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        topic = try container.decode(String.self, forKey: .topic)
        payload = try container.decode(String.self, forKey: .payload)
        payloadFormat = try container.decodeIfPresent(PublishPayloadFormat.self, forKey: .payloadFormat) ?? .text
        qos = try container.decode(QoSLevel.self, forKey: .qos)
        retain = try container.decode(Bool.self, forKey: .retain)
        lastModified = (try? container.decode(Date.self, forKey: .lastModified)) ?? Date()
        mqttContentType = try container.decodeIfPresent(String.self, forKey: .mqttContentType) ?? ""
        responseTopic = try container.decodeIfPresent(String.self, forKey: .responseTopic) ?? ""
        correlationData = try container.decodeIfPresent(String.self, forKey: .correlationData) ?? ""
        messageExpiryInterval = try container.decodeIfPresent(String.self, forKey: .messageExpiryInterval) ?? ""
        payloadFormatIndicator = try container.decodeIfPresent(PayloadFormatIndicatorOption.self, forKey: .payloadFormatIndicator) ?? .unspecified
        userProperties = try container.decodeIfPresent([MQTTUserProperty].self, forKey: .userProperties) ?? []
    }
}

struct PersistedPublishTabs: Codable {
    let connectionId: UUID
    var tabs: [PublishTab]
    var activeTabId: UUID?
    var lastUpdated: Date

    init(connectionId: UUID, tabs: [PublishTab] = [], activeTabId: UUID? = nil) {
        self.connectionId = connectionId
        self.tabs = tabs
        self.activeTabId = activeTabId
        self.lastUpdated = Date()
    }
}
