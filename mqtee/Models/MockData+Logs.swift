import Foundation

extension MockData {
    // MARK: - Log Entries

    static func logEntries(referenceDate: Date = Date(), connectionId: UUID = activeConnectionId) -> [LogEntry] {
        [
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-120),
                level: .info,
                category: .connection,
                message: "Connected to homeassistant.local:1883",
                details: "Client ID: mqtee-ha-001, MQTT 3.1.1",
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-118),
                level: .info,
                category: .subscription,
                message: "Subscribing",
                details: "QoS: 1",
                topic: "homeassistant/sensor/#",
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-117),
                level: .info,
                category: .subscription,
                message: "Subscribing",
                details: "QoS: 0",
                topic: "homeassistant/light/#",
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-116),
                level: .info,
                category: .subscription,
                message: "Subscribing",
                details: "QoS: 0",
                topic: "homeassistant/climate/#",
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-115),
                level: .debug,
                category: .subscription,
                message: "SUBACK received (packet 1)",
                details: "Return codes: 1, 0, 0",
                direction: .incoming,
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-50),
                level: .debug,
                category: .message,
                message: "Message received",
                details: "QoS: 0, Retained: false, Size: 142 bytes",
                topic: "homeassistant/sensor/living_room/temperature",
                direction: .incoming,
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-45),
                level: .info,
                category: .publish,
                message: "Publishing message",
                details: "QoS: 1, Retain: false, Size: 48 bytes",
                topic: "homeassistant/climate/thermostat/set",
                direction: .outgoing,
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-44),
                level: .debug,
                category: .publish,
                message: "PUBACK received (packet 2)",
                direction: .incoming,
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-30),
                level: .debug,
                category: .keepAlive,
                message: "PINGREQ sent",
                direction: .outgoing,
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-29),
                level: .debug,
                category: .keepAlive,
                message: "PINGRESP received",
                direction: .incoming,
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-10),
                level: .warning,
                category: .connection,
                message: "Connection latency spike detected",
                details: "Round-trip: 450ms (threshold: 200ms)",
                connectionId: connectionId
            ),
            LogEntry(
                timestamp: referenceDate.addingTimeInterval(-5),
                level: .debug,
                category: .message,
                message: "Message received",
                details: "QoS: 0, Retained: false, Size: 98 bytes",
                topic: "homeassistant/binary_sensor/motion/hallway",
                direction: .incoming,
                connectionId: connectionId
            ),
        ]
    }

    // MARK: - Log Store Population

    @MainActor
    static func populateLogStore() {
        let logStore = LogStore.shared
        logStore.clear()
        for entry in logEntries() {
            logStore.log(
                level: entry.level,
                category: entry.category,
                message: entry.message,
                details: entry.details,
                topic: entry.topic,
                direction: entry.direction,
                connectionId: entry.connectionId
            )
        }
    }
}
