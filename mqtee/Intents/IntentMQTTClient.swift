//
//  IntentMQTTClient.swift
//  mqtee
//

import Foundation

enum IntentMQTTError: LocalizedError {
    case connectionFailed(String)
    case timeout
    case notConnected

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .timeout:
            return "Operation timed out"
        case .notConnected:
            return "Not connected to broker"
        }
    }
}

final class IntentMQTTClient: MqttEventHandler, @unchecked Sendable {
    private let eventStream: AsyncStream<ConnectionEvent>
    private let eventContinuation: AsyncStream<ConnectionEvent>.Continuation

    init() {
        let (stream, continuation) = AsyncStream<ConnectionEvent>.makeStream()
        self.eventStream = stream
        self.eventContinuation = continuation
    }

    // MARK: - MqttEventHandler

    func onEvent(event: ConnectionEvent) {
        eventContinuation.yield(event)
    }

    // MARK: - Public API

    func connect(connection: Connection, timeoutSeconds: UInt64 = 10) async throws -> MqttClient {
        let credentials = try? KeychainService.shared.loadCredentials(for: connection.id)
        let config = MQTTConnectionConfig(from: connection, credentials: credentials)
        let rustConfig = config.toRustConfig()

        initLogging()
        let client = try MqttClient(config: rustConfig, handler: self)
        try client.connect()

        // Wait for connected/disconnected/error event with timeout
        let result: MqttClient = try await withThrowingTaskGroup(of: MqttClient.self) { group in
            group.addTask {
                for await event in self.eventStream {
                    switch event {
                    case .connected:
                        return client
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

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                throw IntentMQTTError.timeout
            }

            let first = try await group.next()!
            group.cancelAll()
            return first
        }

        return result
    }

    func publish(client: MqttClient, topic: String, payload: Data, qos: QosLevel, retain: Bool) throws {
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
    }

    func getRetainedMessage(client: MqttClient, topic: String, timeoutSeconds: UInt64 = 5) async throws -> String? {
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

        // Wait for first message or timeout
        let result: String? = try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask {
                for await event in self.eventStream {
                    if case .messageReceived(let message) = event {
                        return String(data: message.payload, encoding: .utf8)
                    }
                }
                return nil
            }

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                return nil
            }

            let first = try await group.next() ?? nil
            group.cancelAll()
            return first
        }

        try? client.unsubscribe(topics: [topic])
        return result
    }

    func disconnect(client: MqttClient) {
        try? client.disconnect()
        eventContinuation.finish()
    }
}
