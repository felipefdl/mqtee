import Foundation

// MARK: - MQTT Service Protocol

@MainActor protocol MQTTServiceDelegate: AnyObject {
    func mqttDidConnect()
    func mqttDidDisconnect(reason: String, reasonCode: String?)
    func mqttDidReceiveMessage(_ message: MQTTMessage)
    func mqttDidReceiveMessages(_ messages: [MQTTMessage])
    func mqttDidSubscribe(packetId: UInt16, returnCodes: String, reasonCodesDetail: String?)
    func mqttDidUnsubscribe(packetId: UInt16)
    func mqttDidPublish(packetId: UInt16)
    func mqttDidEncounterError(_ error: String)
    func mqttDidReceiveProtocolEvent(type: String, details: String?, direction: PacketDirection)
}

// MARK: - MQTT Service

final class MQTTService: MqttEventHandler {
    weak var delegate: MQTTServiceDelegate?

    private var client: MqttClient?

    // Batching: collect messages on a background serial queue,
    // dispatch a single Task to the main actor per batch interval.
    let batchQueue = DispatchQueue(label: "mqtee.message-batch")
    var pendingMessages: [MQTTMessage] = []
    var batchFlushScheduled = false

    var isConnected: Bool {
        client?.isConnected() ?? false
    }

    init() {
        initLogging()
    }

    func connect(config: MQTTConnectionConfig) throws {
        let rustConfig = config.toRustConfig()
        client = try MqttClient(config: rustConfig, handler: self)
        try client?.connect()
    }

    func disconnect() throws {
        try client?.disconnect()
    }

    func teardown() {
        client = nil
        batchQueue.async { [weak self] in
            self?.pendingMessages.removeAll()
            self?.batchFlushScheduled = false
        }
    }

    func subscribe(topics: [MQTTSubscriptionConfig]) throws {
        guard isConnected else {
            throw MQTTServiceError.notConnected
        }

        let rustSubs = topics.map { $0.toRustSubscription() }
        try client?.subscribe(subscriptions: rustSubs)
    }

    func unsubscribe(topics: [String]) throws {
        guard isConnected else {
            throw MQTTServiceError.notConnected
        }

        try client?.unsubscribe(topics: topics)
    }

    func publish(
        topic: String,
        payload: Data,
        qos: QoSLevel,
        retain: Bool,
        contentType: String? = nil,
        responseTopic: String? = nil,
        correlationData: Data? = nil,
        messageExpiryInterval: UInt32? = nil,
        payloadFormatIndicator: UInt8? = nil,
        userProperties: [UserProperty] = []
    ) throws {
        guard isConnected else {
            throw MQTTServiceError.notConnected
        }

        try client?.publish(
            topic: topic,
            payload: payload,
            qos: qos.toRust(),
            retain: retain,
            contentType: contentType,
            responseTopic: responseTopic,
            correlationData: correlationData,
            messageExpiryInterval: messageExpiryInterval,
            payloadFormatIndicator: payloadFormatIndicator,
            userProperties: userProperties
        )
    }
}

// MARK: - Errors

enum MQTTServiceError: LocalizedError {
    case notConnected
    case publishFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to broker"
        case .publishFailed(let reason):
            return "Publish failed: \(reason)"
        }
    }
}
