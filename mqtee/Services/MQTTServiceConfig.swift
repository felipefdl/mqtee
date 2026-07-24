import Foundation

// MARK: - Configuration Types

struct MQTTConnectionConfig {
    var clientId: String
    var host: String
    var port: UInt16
    var mqttVersion: MQTTVersion
    var cleanSession: Bool
    var keepAliveSecs: UInt16
    var username: String?
    var password: String?
    var useTLS: Bool
    var allowInsecureTLS: Bool
    var caCertificate: Data?
    var clientCertificate: Data?
    var clientKey: Data?
    var lastWill: MQTTLastWillConfig?
    var sessionExpiryInterval: UInt32?
    var maxPacketSize: UInt32?

    init(from connection: Connection, credentials: ConnectionCredentials? = nil) {
        self.clientId = MQTTService.deviceClientId(for: connection.id)
        self.host = connection.host
        self.port = UInt16(connection.port)
        self.mqttVersion = connection.mqttVersion
        self.cleanSession = connection.cleanSession
        self.keepAliveSecs = UInt16(connection.keepAlive)
        self.username = credentials?.username ?? connection.username
        self.password = credentials?.password
        self.useTLS = connection.useTLS
        self.allowInsecureTLS = connection.allowInsecureTLS
        self.caCertificate = credentials?.caCertificate
        self.clientCertificate = credentials?.clientCertificate
        self.clientKey = credentials?.clientKey
        self.sessionExpiryInterval = connection.sessionExpiry.map { UInt32($0) }
        self.maxPacketSize = nil

        if connection.lastWill.enabled {
            self.lastWill = MQTTLastWillConfig(
                topic: connection.lastWill.topic,
                message: connection.lastWill.message,
                qos: connection.lastWill.qos,
                retain: connection.lastWill.retain
            )
        } else {
            self.lastWill = nil
        }
    }

    func toRustConfig() -> ConnectionConfig {
        ConnectionConfig(
            clientId: clientId,
            host: host,
            port: port,
            mqttVersion: mqttVersion.toRust(),
            cleanSession: cleanSession,
            keepAliveSecs: keepAliveSecs,
            username: username,
            password: password,
            useTls: useTLS,
            allowInsecureTls: allowInsecureTLS,
            caCertificate: caCertificate,
            clientCertificate: clientCertificate,
            clientKey: clientKey,
            lastWill: lastWill?.toRust(),
            sessionExpiryInterval: sessionExpiryInterval,
            maxPacketSize: maxPacketSize
        )
    }
}

struct MQTTLastWillConfig {
    var topic: String
    var message: String
    var qos: QoSLevel
    var retain: Bool

    func toRust() -> LastWillConfig {
        LastWillConfig(
            topic: topic,
            message: message,
            qos: qos.toRust(),
            retain: retain
        )
    }
}

struct MQTTSubscriptionConfig {
    var topic: String
    var qos: QoSLevel
    var noLocal: Bool
    var retainAsPublished: Bool
    var retainHandling: UInt8

    init(topic: String, qos: QoSLevel, noLocal: Bool = false, retainAsPublished: Bool = false, retainHandling: UInt8 = 0) {
        self.topic = topic
        self.qos = qos
        self.noLocal = noLocal
        self.retainAsPublished = retainAsPublished
        self.retainHandling = retainHandling
    }

    func toRustSubscription() -> SubscriptionRequest {
        SubscriptionRequest(
            topic: topic,
            qos: qos.toRust(),
            noLocal: noLocal,
            retainAsPublished: retainAsPublished,
            retainHandling: retainHandling
        )
    }
}

// MARK: - Rust Type Conversions

extension MQTTVersion {
    func toRust() -> MqttVersion {
        switch self {
        case .v311: return .v311
        case .v5: return .v5
        }
    }
}

extension QoSLevel {
    func toRust() -> QosLevel {
        switch self {
        case .atMostOnce: return .atMostOnce
        case .atLeastOnce: return .atLeastOnce
        case .exactlyOnce: return .exactlyOnce
        }
    }

    static func fromRust(_ qos: QosLevel) -> QoSLevel {
        switch qos {
        case .atMostOnce: return .atMostOnce
        case .atLeastOnce: return .atLeastOnce
        case .exactlyOnce: return .exactlyOnce
        }
    }
}
