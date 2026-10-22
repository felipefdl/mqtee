//
//  ConnectionEditorView+Testing.swift
//  mqtee
//

import os
import SwiftUI

extension ConnectionEditorView {
    var testConnectionSection: some View {
        Section {
            HStack {
                Spacer()
                testConnectionButton
                Spacer()
            }
        }
    }

    @ViewBuilder
    var testConnectionButton: some View {
        switch testStatus {
        case .idle:
            Button("Test Connection") {
                Task { await testConnection() }
            }
            .buttonStyle(.glass)
            .disabled(host.isEmpty)

        case .testing:
            Button {} label: {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Testing...")
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.glass)
            .allowsHitTesting(false)

        case .success:
            Button {} label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connected")
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.glass)
            .allowsHitTesting(false)

        case .failure:
            Button("Test Connection") {
                Task { await testConnection() }
            }
            .buttonStyle(.glass)
            .disabled(host.isEmpty)
        }
    }

    func testConnection() async {
        let ranges: MQTTConnectionConfigError.Ranges
        do {
            ranges = try MQTTConnectionConfigError.validate(port: port, keepAlive: keepAlive, sessionExpiry: "")
        } catch {
            testStatus = .failure(error.localizedDescription)
            testErrorMessage = error.localizedDescription
            return
        }
        testStatus = .testing

        let portNumber = ranges.port
        let effectiveClientId = clientId.isEmpty ? "mqtee-test-\(UUID().uuidString.prefix(8))" : clientId
        let keepAliveSeconds = ranges.keepAlive

        var lastWillConfig: LastWillConfig?
        if lastWillEnabled && !lastWillTopic.isEmpty {
            lastWillConfig = LastWillConfig(
                topic: lastWillTopic,
                message: lastWillMessage,
                qos: lastWillQoS.toRust(),
                retain: lastWillRetain
            )
        }

        let config = ConnectionConfig(
            clientId: effectiveClientId,
            host: host,
            port: portNumber,
            mqttVersion: mqttVersion.toRust(),
            cleanSession: true,
            keepAliveSecs: keepAliveSeconds,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            useTls: useTLS,
            allowInsecureTls: allowInsecureTLS,
            caCertificate: caCertificateData,
            clientCertificate: clientCertificateData,
            clientKey: clientKeyData,
            lastWill: lastWillConfig,
            sessionExpiryInterval: nil,
            maxPacketSize: nil
        )

        do {
            let result: ConnectionTestStatus = try await withCheckedThrowingContinuation { continuation in
                final class TestHandler: MqttEventHandler, @unchecked Sendable {
                    private struct State {
                        var resumed = false
                        var client: MqttClient?
                    }

                    let continuation: CheckedContinuation<ConnectionTestStatus, any Error>
                    private let lock = OSAllocatedUnfairLock(initialState: State())

                    init(continuation: CheckedContinuation<ConnectionTestStatus, any Error>) {
                        self.continuation = continuation
                    }

                    /// Stores the client; disconnects right away if the test already resolved.
                    func attach(_ client: MqttClient) {
                        let alreadyResolved = lock.withLock { state in
                            state.client = client
                            return state.resumed
                        }
                        if alreadyResolved {
                            try? client.disconnect()
                        }
                    }

                    /// Resolves the test once, then disconnects the client.
                    func finish(_ result: Result<ConnectionTestStatus, any Error>) {
                        let (won, client) = lock.withLock { state -> (Bool, MqttClient?) in
                            guard !state.resumed else { return (false, nil) }
                            state.resumed = true
                            return (true, state.client)
                        }
                        guard won else { return }
                        continuation.resume(with: result)
                        if let client {
                            Task { try? client.disconnect() }
                        }
                    }

                    func onEvent(event: ConnectionEvent) {
                        switch event {
                        case .connected:
                            finish(.success(.success))
                        case .error(let message):
                            finish(.success(.failure(message)))
                        case .disconnected(let reason, _):
                            finish(.success(.failure(reason)))
                        default:
                            break
                        }
                    }
                }

                let handler = TestHandler(continuation: continuation)

                do {
                    let client = try MqttClient(config: config, handler: handler)
                    handler.attach(client)
                    try client.connect()

                    // Timeout after 15 seconds: slow TLS handshakes on public brokers need more than a few seconds
                    Task {
                        try? await Task.sleep(for: .seconds(15))
                        handler.finish(.success(.failure("Connection timed out")))
                    }
                } catch {
                    handler.finish(.failure(error))
                }
            }

            testStatus = result
            if case .failure(let message) = result {
                testErrorMessage = message
            }
        } catch {
            testStatus = .failure(error.localizedDescription)
            testErrorMessage = error.localizedDescription
        }

        // Reset to idle after showing success briefly
        if case .success = testStatus {
            try? await Task.sleep(for: .seconds(2))
            testStatus = .idle
        }
    }
}
