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
        testStatus = .testing

        let portNumber = UInt16(port) ?? 1883
        let effectiveClientId = clientId.isEmpty ? "mqtee-test-\(UUID().uuidString.prefix(8))" : clientId
        let keepAliveSeconds = UInt16(keepAlive) ?? 60

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
                class TestHandler: MqttEventHandler, @unchecked Sendable {
                    let continuation: CheckedContinuation<ConnectionTestStatus, any Error>
                    private let lock = OSAllocatedUnfairLock(initialState: false)

                    init(continuation: CheckedContinuation<ConnectionTestStatus, any Error>) {
                        self.continuation = continuation
                    }

                    func markResumed() -> Bool {
                        lock.withLock { resumed in
                            guard !resumed else { return false }
                            resumed = true
                            return true
                        }
                    }

                    func onEvent(event: ConnectionEvent) {
                        switch event {
                        case .connected:
                            if markResumed() {
                                continuation.resume(returning: .success)
                            }
                        case .error(let message):
                            if markResumed() {
                                continuation.resume(returning: .failure(message))
                            }
                        case .disconnected(let reason, _):
                            if markResumed() {
                                continuation.resume(returning: .failure(reason))
                            }
                        default:
                            break
                        }
                    }
                }

                let handler = TestHandler(continuation: continuation)

                do {
                    let client = try MqttClient(config: config, handler: handler)
                    try client.connect()

                    // Timeout after 5 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(5))
                        if handler.markResumed() {
                            try? client.disconnect()
                            continuation.resume(returning: .failure("Connection timed out"))
                        }
                    }

                    // Disconnect after success is captured by the handler
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        try? client.disconnect()
                    }
                } catch {
                    if handler.markResumed() {
                        continuation.resume(throwing: error)
                    }
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
