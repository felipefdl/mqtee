//
//  Connection.swift
//  mqtee
//

import Foundation
import SwiftUI

// MARK: - MQTT Version

enum MQTTVersion: String, CaseIterable, Codable, Hashable {
    case v311 = "3.1.1"
    case v5 = "5.0"
    
    var displayName: String {
        switch self {
        case .v311: return "MQTT 3.1.1"
        case .v5: return "MQTT 5.0"
        }
    }
    
}

// MARK: - QoS Level

enum QoSLevel: Int, CaseIterable, Codable, Hashable {
    case atMostOnce = 0
    case atLeastOnce = 1
    case exactlyOnce = 2
    
    var displayName: String {
        switch self {
        case .atMostOnce: return "QoS 0 - At most once"
        case .atLeastOnce: return "QoS 1 - At least once"
        case .exactlyOnce: return "QoS 2 - Exactly once"
        }
    }

    var shortName: String {
        switch self {
        case .atMostOnce: return "QoS 0"
        case .atLeastOnce: return "QoS 1"
        case .exactlyOnce: return "QoS 2"
        }
    }
}

// MARK: - Last Will and Testament

struct LastWillSettings: Codable, Hashable {
    var enabled: Bool = false
    var topic: String = ""
    var message: String = ""
    var qos: QoSLevel = .atMostOnce
    var retain: Bool = false
}

// MARK: - Connection

/// Connection metadata stored in iCloud.
/// Sensitive credentials (password, certificates) are stored separately in Keychain.
struct Connection: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var folderId: UUID?
    
    // MQTT Settings
    var mqttVersion: MQTTVersion
    var clientId: String
    var cleanSession: Bool
    var keepAlive: Int
    var sessionExpiry: Int? // MQTT 5.0 only
    
    // Authentication
    var username: String?
    
    // TLS/Security
    var useTLS: Bool
    var useClientCertificate: Bool
    var allowInsecureTLS: Bool
    
    // Last Will and Testament
    var lastWill: LastWillSettings
    
    // Session Persistence
    var persistSession: Bool

    // Auto-Subscribe
    var autoSubscribe: Bool

    // Tracking
    var createdAt: Date?
    var lastConnectedAt: Date?
    
    // Password is NOT stored here - use KeychainService
    
    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 1883,
        folderId: UUID? = nil,
        mqttVersion: MQTTVersion = .v311,
        clientId: String = "",
        cleanSession: Bool = true,
        keepAlive: Int = 60,
        sessionExpiry: Int? = nil,
        username: String? = nil,
        useTLS: Bool = false,
        useClientCertificate: Bool = false,
        allowInsecureTLS: Bool = false,
        lastWill: LastWillSettings = LastWillSettings(),
        persistSession: Bool = true,
        autoSubscribe: Bool = false,
        createdAt: Date? = Date(),
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.folderId = folderId
        self.mqttVersion = mqttVersion
        self.clientId = clientId.isEmpty ? "mqtee-\(UUID().uuidString.prefix(8))" : clientId
        self.cleanSession = cleanSession
        self.keepAlive = keepAlive
        self.sessionExpiry = sessionExpiry
        self.username = username
        self.useTLS = useTLS
        self.useClientCertificate = useClientCertificate
        self.allowInsecureTLS = allowInsecureTLS
        self.lastWill = lastWill
        self.persistSession = persistSession
        self.autoSubscribe = autoSubscribe
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        folderId = try container.decodeIfPresent(UUID.self, forKey: .folderId)
        mqttVersion = try container.decode(MQTTVersion.self, forKey: .mqttVersion)
        clientId = try container.decode(String.self, forKey: .clientId)
        cleanSession = try container.decode(Bool.self, forKey: .cleanSession)
        keepAlive = try container.decode(Int.self, forKey: .keepAlive)
        sessionExpiry = try container.decodeIfPresent(Int.self, forKey: .sessionExpiry)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        useTLS = try container.decode(Bool.self, forKey: .useTLS)
        useClientCertificate = try container.decode(Bool.self, forKey: .useClientCertificate)
        allowInsecureTLS = try container.decode(Bool.self, forKey: .allowInsecureTLS)
        lastWill = try container.decode(LastWillSettings.self, forKey: .lastWill)
        persistSession = try container.decode(Bool.self, forKey: .persistSession)
        autoSubscribe = try container.decodeIfPresent(Bool.self, forKey: .autoSubscribe) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        lastConnectedAt = try container.decodeIfPresent(Date.self, forKey: .lastConnectedAt)
    }

    var subtitle: String {
        if let username = username, !username.isEmpty {
            return "\(username)@\(host):\(port)"
        }
        return "\(host):\(port)"
    }
}

struct ConnectionFolder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var color: FolderColor
    
    init(id: UUID = UUID(), name: String, color: FolderColor = .blue) {
        self.id = id
        self.name = name
        self.color = color
    }
}

enum FolderColor: String, CaseIterable, Hashable, Codable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }

    var localizedName: String {
        switch self {
        case .red: return String(localized: "Red", comment: "Folder color")
        case .orange: return String(localized: "Orange", comment: "Folder color")
        case .yellow: return String(localized: "Yellow", comment: "Folder color")
        case .green: return String(localized: "Green", comment: "Folder color")
        case .blue: return String(localized: "Blue", comment: "Folder color")
        case .purple: return String(localized: "Purple", comment: "Folder color")
        case .pink: return String(localized: "Pink", comment: "Folder color")
        }
    }
}
