//
//  IntentMQTTClient.swift
//  mqtee
//

import Foundation

enum IntentMQTTError: LocalizedError {
    case connectionFailed(String)
    case publishFailed(String)
    case timeout
    case notConnected

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .publishFailed(let reason):
            return "Publish failed: \(reason)"
        case .timeout:
            return "Operation timed out"
        case .notConnected:
            return "Not connected to broker"
        }
    }
}

final class IntentMQTTClient: MqttEventHandler, @unchecked Sendable {
    nonisolated static let timeoutRange = 1...300

    private let eventStream: AsyncStream<ConnectionEvent>
    private let eventContinuation: AsyncStream<ConnectionEvent>.Continuation

    init() {
        let (stream, continuation) = AsyncStream<ConnectionEvent>.makeStream()
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    /// Clamps a user-supplied timeout in seconds into the supported range and converts it to a `Duration`.
    nonisolated static func timeoutDuration(seconds: Int) -> Duration {
        .seconds(min(max(seconds, timeoutRange.lowerBound), timeoutRange.upperBound))
    }

    /// A client ID unique to this invocation so it never evicts the interactive session that uses the device ID.
    /// Kept within the 23-character limit MQTT 3.1.1 guarantees brokers accept.
    static func invocationClientId(for connectionId: UUID) -> String {
        let base = String(MQTTService.deviceClientId(for: connectionId).prefix(16))
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6).lowercased()
        return "\(base)-\(suffix)"
    }

    // MARK: - MqttEventHandler

    func onEvent(event: ConnectionEvent) {
        eventContinuation.yield(event)
    }

    // MARK: - Public API

    func connect(connection: Connection, timeout: Duration) async throws -> MqttClient {
        let credentials = try? KeychainService.shared.loadCredentials(for: connection.id)
        var config = try MQTTConnectionConfig(from: connection, credentials: credentials)
        config.clientId = Self.invocationClientId(for: connection.id)
        config.cleanSession = true
        if config.sessionExpiryInterval != nil {
            config.sessionExpiryInterval = 0
        }
        let rustConfig = config.toRustConfig()

        initLogging()
        let client = try MqttClient(config: rustConfig, handler: self)
        try client.connect()

        // Wait for connected/disconnected/error event with timeout
        do {
            try await withTimeout(timeout) {
                for await event in self.eventStream {
                    switch event {
                    case .connected:
                        return
                    case .disconnected(let reason, _):
                        throw IntentMQTTError.connectionFailed(reason)
                    case .error(let error):
                        throw IntentMQTTError.connectionFailed(error)
                    default:
                        continue
                    }
                }
                throw IntentMQTTError.connectionFailed("Event stream ended unexpectedly")
            }
        } catch {
            disconnect(client: client)
            throw error
        }

        return client
    }

    /// Publishes and returns only after the broker-level confirmation for the QoS arrives:
    /// QoS 0 the outgoing publish, QoS 1 the PUBACK, QoS 2 the PUBCOMP.
    func publish(
        client: MqttClient,
        topic: String,
        payload: Data,
        qos: QosLevel,
        retain: Bool,
        timeout: Duration
    ) async throws {
        guard client.isConnected() else {
            throw IntentMQTTError.notConnected
        }
        try client.publish(
            topic: topic,
            payload: payload,
            qos: qos,
            retain: retain,
            contentType: nil,
            responseTopic: nil,
            correlationData: nil,
            messageExpiryInterval: nil,
            payloadFormatIndicator: nil,
            userProperties: []
        )

        let level: Int
        switch qos {
        case .atMostOnce: level = 0
        case .atLeastOnce: level = 1
        case .exactlyOnce: level = 2
        }

        try await withTimeout(timeout) {
            var sentPacketId: UInt16?
            for await event in self.eventStream {
                switch event {
                case .publishSent(let packetId):
                    if level == 0 { return }
                    sentPacketId = packetId
                case .publishAck(let packetId) where level == 1 && packetId == sentPacketId:
                    return
                case .pubCompReceived(let packetId) where level == 2 && packetId == sentPacketId:
                    return
                case .error(let error):
                    throw IntentMQTTError.publishFailed(error)
                case .disconnected(let reason, _):
                    throw IntentMQTTError.publishFailed(reason)
                default:
                    continue
                }
            }
            throw IntentMQTTError.publishFailed("Event stream ended unexpectedly")
        }
    }

    func getRetainedMessage(client: MqttClient, topic: String, timeout: Duration) async throws -> String? {
        guard client.isConnected() else {
            throw IntentMQTTError.notConnected
        }

        let subscription = SubscriptionRequest(
            topic: topic,
            qos: QosLevel.atMostOnce,
            noLocal: false,
            retainAsPublished: false,
            retainHandling: 0
        )
        try client.subscribe(subscriptions: [subscription])

        // Wait for first message or timeout (timeout means no retained value)
        let result: String?
        do {
            result = try await withTimeout(timeout) {
                for await event in self.eventStream {
                    if case .messageReceived(let message) = event {
                        return String(data: message.payload, encoding: .utf8)
                    }
                }
                return nil
            }
        } catch IntentMQTTError.timeout {
            result = nil
        }

        try? client.unsubscribe(topics: [topic])
        return result
    }

    func disconnect(client: MqttClient) {
        try? client.disconnect()
        eventContinuation.finish()
    }

    // MARK: - Helpers

    private func withTimeout<T: Sendable>(
        _ timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw IntentMQTTError.timeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw IntentMQTTError.timeout }
            return first
        }
    }
}
