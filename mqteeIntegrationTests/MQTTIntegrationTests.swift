#if INTEGRATION_TESTS
import Testing
import Foundation
@testable import MQTee

@Suite("MQTT Integration", .serialized)
struct MQTTIntegrationTests {

    static let host = "127.0.0.1"
    static let port: UInt16 = 18830
    static let tlsPort: UInt16 = 18831

    private func makeConfig(
        clientId: String? = nil,
        port: UInt16 = MQTTIntegrationTests.port,
        useTls: Bool = false,
        allowInsecureTls: Bool = false
    ) -> ConnectionConfig {
        ConnectionConfig(
            clientId: clientId ?? "mqtee-test-\(UUID().uuidString.prefix(8))",
            host: Self.host,
            port: port,
            mqttVersion: .v311,
            cleanSession: true,
            keepAliveSecs: 30,
            username: nil,
            password: nil,
            useTls: useTls,
            allowInsecureTls: allowInsecureTls,
            caCertificate: nil,
            clientCertificate: nil,
            clientKey: nil,
            lastWill: nil,
            sessionExpiryInterval: nil,
            maxPacketSize: nil
        )
    }

    @Test("Connect and disconnect cycle")
    func connectAndDisconnect() async throws {
        let config = makeConfig()

        let connectedExpectation = UncheckedSendableBox(value: false)
        let handler = TestEventHandler { event in
            if case .connected = event {
                connectedExpectation.value = true
            }
        }

        let client = try MqttClient(config: config, handler: handler)
        try client.connect()
        try await Task.sleep(for: .seconds(1))

        #expect(connectedExpectation.value == true)
        try client.disconnect()
        try await Task.sleep(for: .milliseconds(500))
    }

    @Test("Subscribe and receive published message")
    func subscribeAndReceive() async throws {
        let uniqueTopic = "mqtee-test/\(UUID().uuidString)"
        let expectedPayload = "test-payload-\(UUID().uuidString.prefix(8))"

        let pubConfig = makeConfig()
        let subConfig = makeConfig()

        let receivedMessage = UncheckedSendableBox<String?>(value: nil)
        let subConnected = UncheckedSendableBox(value: false)

        let subHandler = TestEventHandler { event in
            switch event {
            case .connected:
                subConnected.value = true
            case .messageReceived(let message):
                if message.topic == uniqueTopic {
                    receivedMessage.value = String(data: message.payload, encoding: .utf8)
                }
            default:
                break
            }
        }

        let pubConnected = UncheckedSendableBox(value: false)
        let pubHandler = TestEventHandler { event in
            if case .connected = event {
                pubConnected.value = true
            }
        }

        let subClient = try MqttClient(config: subConfig, handler: subHandler)
        try subClient.connect()
        try await Task.sleep(for: .seconds(1))
        #expect(subConnected.value == true)

        try subClient.subscribe(subscriptions: [SubscriptionRequest(topic: uniqueTopic, qos: .atMostOnce, noLocal: false, retainAsPublished: false, retainHandling: 0)])
        try await Task.sleep(for: .milliseconds(500))

        let pubClient = try MqttClient(config: pubConfig, handler: pubHandler)
        try pubClient.connect()
        try await Task.sleep(for: .seconds(1))
        #expect(pubConnected.value == true)

        try pubClient.publish(
            topic: uniqueTopic,
            payload: expectedPayload.data(using: .utf8)!,
            qos: .atMostOnce,
            retain: false,
            contentType: nil,
            responseTopic: nil,
            correlationData: nil,
            messageExpiryInterval: nil,
            payloadFormatIndicator: nil,
            userProperties: []
        )
        try await Task.sleep(for: .seconds(1))

        #expect(receivedMessage.value == expectedPayload)

        try pubClient.disconnect()
        try subClient.disconnect()
        try await Task.sleep(for: .milliseconds(500))
    }

    @Test("QoS 1 publish")
    func qos1Publish() async throws {
        let config = makeConfig()
        let connected = UncheckedSendableBox(value: false)
        let ackReceived = UncheckedSendableBox(value: false)

        let handler = TestEventHandler { event in
            switch event {
            case .connected:
                connected.value = true
            case .publishAck:
                ackReceived.value = true
            default:
                break
            }
        }

        let client = try MqttClient(config: config, handler: handler)
        try client.connect()
        try await Task.sleep(for: .seconds(1))
        #expect(connected.value == true)

        let topic = "mqtee-test/qos1/\(UUID().uuidString)"
        try client.publish(topic: topic, payload: "qos1-test".data(using: .utf8)!, qos: .atLeastOnce, retain: false, contentType: nil, responseTopic: nil, correlationData: nil, messageExpiryInterval: nil, payloadFormatIndicator: nil, userProperties: [])
        try await Task.sleep(for: .seconds(1))

        #expect(ackReceived.value == true)
        try client.disconnect()
    }

    @Test("TLS connection")
    func tlsConnection() async throws {
        let config = makeConfig(port: Self.tlsPort, useTls: true, allowInsecureTls: true)
        let connected = UncheckedSendableBox(value: false)
        let lastError = UncheckedSendableBox<String?>(value: nil)

        let handler = TestEventHandler { event in
            switch event {
            case .connected:
                connected.value = true
            case .error(let error):
                lastError.value = error
            default:
                break
            }
        }

        let client = try MqttClient(config: config, handler: handler)
        try client.connect()
        try await Task.sleep(for: .seconds(2))

        if let error = lastError.value {
            Issue.record("TLS connection error: \(error)")
        }
        #expect(connected.value == true)
        try client.disconnect()
    }
}

// MARK: - Test Helpers

final class UncheckedSendableBox<T>: @unchecked Sendable {
    var value: T

    init(value: T) {
        self.value = value
    }
}

final class TestEventHandler: MqttEventHandler {
    private let callback: @Sendable (ConnectionEvent) -> Void

    init(callback: @escaping @Sendable (ConnectionEvent) -> Void) {
        self.callback = callback
    }

    func onEvent(event: ConnectionEvent) {
        callback(event)
    }
}
#endif
