//
//  GetRetainedValueIntent.swift
//  mqtee
//

import AppIntents
import Foundation

struct GetRetainedValueIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Retained MQTT Value"
    static var description: IntentDescription = "Get the last retained value from an MQTT topic"

    @Parameter(title: "Connection")
    var connection: ConnectionEntity

    @Parameter(title: "Topic")
    var topic: String

    @Parameter(title: "Timeout (seconds)", default: 5, inclusiveRange: (1, 300))
    var timeout: Int

    /// Main actor: the intent client and the generated UniFFI bindings are main-actor isolated.
    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let connections = ConnectionEntityQuery.loadConnections()
        guard let conn = connections.first(where: { $0.id == connection.id }) else {
            throw IntentMQTTError.connectionFailed("Connection not found")
        }

        let timeoutDuration = IntentMQTTClient.timeoutDuration(seconds: timeout)
        let mqttClient = IntentMQTTClient()
        let client = try await mqttClient.connect(connection: conn, timeout: timeoutDuration)

        defer { mqttClient.disconnect(client: client) }

        let value = try await mqttClient.getRetainedMessage(client: client, topic: topic, timeout: timeoutDuration)

        return .result(value: value ?? "")
    }

}
