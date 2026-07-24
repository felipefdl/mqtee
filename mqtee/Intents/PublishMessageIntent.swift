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

    @Parameter(title: "Timeout (seconds)", default: 10)
    var timeout: Int

    func perform() async throws -> some IntentResult {
        let connections = ConnectionEntityQuery.loadConnections()
        guard let conn = connections.first(where: { $0.id == connection.id }) else {
            throw IntentMQTTError.connectionFailed("Connection not found")
        }

        let mqttClient = IntentMQTTClient()
        let client = try await mqttClient.connect(connection: conn, timeoutSeconds: UInt64(timeout))

        defer { mqttClient.disconnect(client: client) }

        let payloadData = Data(payload.utf8)

        try mqttClient.publish(client: client, topic: topic, payload: payloadData, qos: qos.qosLevel, retain: retain)

        return .result()
    }

}
