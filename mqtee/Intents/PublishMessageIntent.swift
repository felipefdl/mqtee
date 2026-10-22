//
//  PublishMessageIntent.swift
//  mqtee
//

import AppIntents
import Foundation

enum QoSLevelAppEnum: Int, AppEnum {
    case atMostOnce = 0
    case atLeastOnce = 1
    case exactlyOnce = 2

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "QoS Level"

    static var caseDisplayRepresentations: [QoSLevelAppEnum: DisplayRepresentation] = [
        .atMostOnce: "QoS 0 - At most once",
        .atLeastOnce: "QoS 1 - At least once",
        .exactlyOnce: "QoS 2 - Exactly once",
    ]

    var qosLevel: QosLevel {
        switch self {
        case .atMostOnce: .atMostOnce
        case .atLeastOnce: .atLeastOnce
        case .exactlyOnce: .exactlyOnce
        }
    }
}

struct PublishMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Publish MQTT Message"
    static var description: IntentDescription = "Publish a message to an MQTT topic"

    @Parameter(title: "Connection")
    var connection: ConnectionEntity

    @Parameter(title: "Topic")
    var topic: String

    @Parameter(title: "Payload", inputOptions: String.IntentInputOptions(multiline: true))
    var payload: String

    @Parameter(title: "QoS", default: .atMostOnce)
    var qos: QoSLevelAppEnum

    @Parameter(title: "Retain", default: false)
    var retain: Bool

    @Parameter(title: "Timeout (seconds)", default: 10, inclusiveRange: (1, 300))
    var timeout: Int

    /// Main actor: the intent client and the generated UniFFI bindings are main-actor isolated.
    /// Every MQTT call only enqueues work for the Rust runtime, so nothing here blocks the main thread.
    @MainActor
    func perform() async throws -> some IntentResult {
        let connections = ConnectionEntityQuery.loadConnections()
        guard let conn = connections.first(where: { $0.id == connection.id }) else {
            throw IntentMQTTError.connectionFailed("Connection not found")
        }

        let timeoutDuration = IntentMQTTClient.timeoutDuration(seconds: timeout)
        let mqttClient = IntentMQTTClient()
        let client = try await mqttClient.connect(connection: conn, timeout: timeoutDuration)

        defer { mqttClient.disconnect(client: client) }

        let payloadData = Data(payload.utf8)

        try await mqttClient.publish(
            client: client,
            topic: topic,
            payload: payloadData,
            qos: qos.qosLevel,
            retain: retain,
            timeout: timeoutDuration
        )

        return .result()
    }

}
