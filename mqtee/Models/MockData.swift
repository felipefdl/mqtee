//
//  MockData.swift
//  mqtee
//
//  Mock data provider for screenshot mode and SwiftUI previews.
//  Activated via --screenshot-mode launch argument.
//

import Foundation
import SwiftUI

enum MockData {

    // MARK: - Stable UUIDs (deterministic for screenshots)

    private static let folderHomeId = UUID(uuidString: "00000001-0001-0001-0001-000000000001")!
    private static let folderProdId = UUID(uuidString: "00000001-0001-0001-0001-000000000002")!
    private static let folderDevId = UUID(uuidString: "00000001-0001-0001-0001-000000000003")!

    private static let connHomeAssistantId = UUID(uuidString: "00000002-0002-0002-0002-000000000001")!
    private static let connZigbee2MQTTId = UUID(uuidString: "00000002-0002-0002-0002-000000000007")!
    private static let connAwsIoTId = UUID(uuidString: "00000002-0002-0002-0002-000000000002")!
    private static let connFactoryId = UUID(uuidString: "00000002-0002-0002-0002-000000000003")!
    private static let connStagingId = UUID(uuidString: "00000002-0002-0002-0002-000000000004")!
    private static let connLocalId = UUID(uuidString: "00000002-0002-0002-0002-000000000005")!
    private static let connTestBrokerId = UUID(uuidString: "00000002-0002-0002-0002-000000000006")!

    // MARK: - Folders

    static let folders: [ConnectionFolder] = [
        ConnectionFolder(id: folderHomeId, name: "Home", color: .green),
        ConnectionFolder(id: folderProdId, name: "Production", color: .red),
        ConnectionFolder(id: folderDevId, name: "Development", color: .blue),
    ]

    // MARK: - Connections

    static let connections: [Connection] = [
        Connection(
            id: connHomeAssistantId,
            name: "Home Assistant",
            host: "homeassistant.local",
            port: 1883,
            folderId: folderHomeId,
            mqttVersion: .v311,
            clientId: "mqtee-ha-001",
            keepAlive: 60,
            username: "homeassistant",
            persistSession: true,
            createdAt: Date().addingTimeInterval(-86400 * 30),
            lastConnectedAt: Date().addingTimeInterval(-120)
        ),
        Connection(
            id: connZigbee2MQTTId,
            name: "Zigbee2MQTT",
            host: "homeassistant.local",
            port: 1883,
            folderId: folderHomeId,
            mqttVersion: .v311,
            clientId: "mqtee-z2m-001",
            keepAlive: 60,
            username: "homeassistant",
            persistSession: true,
            createdAt: Date().addingTimeInterval(-86400 * 28),
            lastConnectedAt: Date().addingTimeInterval(-300)
        ),
        Connection(
            id: connAwsIoTId,
            name: "Cloud IoT",
            host: "iot.example.com",
            port: 8883,
            folderId: folderProdId,
            mqttVersion: .v5,
            clientId: "mqtee-cloud-prod",
            cleanSession: false,
            keepAlive: 30,
            sessionExpiry: 3600,
            useTLS: true,
            useClientCertificate: true,
            persistSession: true,
            createdAt: Date().addingTimeInterval(-86400 * 60),
            lastConnectedAt: Date().addingTimeInterval(-3600)
        ),
        Connection(
            id: connFactoryId,
            name: "Factory Floor",
            host: "mqtt.factory.internal",
            port: 8883,
            folderId: folderProdId,
            mqttVersion: .v5,
            clientId: "mqtee-factory",
            keepAlive: 15,
            username: "supervisor",
            useTLS: true,
            lastWill: LastWillSettings(
                enabled: true,
                topic: "factory/supervisor/status",
                message: "{\"status\": \"offline\"}",
                qos: .atLeastOnce,
                retain: true
            ),
            persistSession: true,
            createdAt: Date().addingTimeInterval(-86400 * 45),
            lastConnectedAt: Date().addingTimeInterval(-7200)
        ),
        Connection(
            id: connStagingId,
            name: "Staging Broker",
            host: "mqtt-staging.example.com",
            port: 1883,
            folderId: folderDevId,
            mqttVersion: .v311,
            clientId: "mqtee-staging",
            keepAlive: 60,
            username: "developer",
            persistSession: true,
            createdAt: Date().addingTimeInterval(-86400 * 14),
            lastConnectedAt: Date().addingTimeInterval(-86400)
        ),
        Connection(
            id: connLocalId,
            name: "Local Broker",
            host: "localhost",
            port: 1883,
            folderId: folderDevId,
            mqttVersion: .v5,
            clientId: "mqtee-local",
            keepAlive: 60,
            createdAt: Date().addingTimeInterval(-86400 * 7),
            lastConnectedAt: Date().addingTimeInterval(-600)
        ),
        Connection(
            id: connTestBrokerId,
            name: "Public Test Broker",
            host: "broker.hivemq.com",
            port: 1883,
            mqttVersion: .v311,
            clientId: "mqtee-test",
            keepAlive: 60,
            createdAt: Date().addingTimeInterval(-86400 * 3)
        ),
    ]

    // MARK: - Active Session (Home Assistant)

    static let activeConnectionId = connHomeAssistantId

    static var activeConnection: Connection {
        connections.first { $0.id == activeConnectionId }!
    }

    static let subscriptions: [Subscription] = [
        Subscription(topic: "homeassistant/sensor/#", qos: .atLeastOnce, color: .blue),
        Subscription(topic: "homeassistant/light/#", qos: .atMostOnce, color: .green),
        Subscription(topic: "homeassistant/climate/#", qos: .atMostOnce, color: .orange),
        Subscription(topic: "homeassistant/binary_sensor/#", qos: .atLeastOnce, color: .purple),
    ]

    static func messages(referenceDate: Date = Date()) -> [MQTTMessage] {
        let msgs: [(String, String, Bool, Int)] = [
            ("homeassistant/sensor/living_room/temperature", """
            {"state": "22.5", "attributes": {"unit_of_measurement": "\u{00B0}C", "friendly_name": "Living Room Temperature", "device_class": "temperature"}}
            """, false, -5),
            ("homeassistant/sensor/living_room/humidity", """
            {"state": "45", "attributes": {"unit_of_measurement": "%", "friendly_name": "Living Room Humidity", "device_class": "humidity"}}
            """, false, -8),
            ("homeassistant/light/kitchen/state", """
            {"state": "on", "attributes": {"brightness": 200, "color_temp": 370, "friendly_name": "Kitchen Light"}}
            """, false, -12),
            ("homeassistant/climate/thermostat/state", """
            {"state": "heat", "attributes": {"temperature": 21.0, "current_temperature": 20.3, "hvac_action": "heating", "friendly_name": "Thermostat"}}
            """, false, -15),
            ("homeassistant/sensor/bedroom/temperature", """
            {"state": "19.8", "attributes": {"unit_of_measurement": "\u{00B0}C", "friendly_name": "Bedroom Temperature", "device_class": "temperature"}}
            """, false, -20),
            ("homeassistant/binary_sensor/front_door/state", """
            {"state": "off", "attributes": {"device_class": "door", "friendly_name": "Front Door"}}
            """, false, -22),
            ("homeassistant/sensor/garage/door", """
            {"state": "closed", "attributes": {"device_class": "garage_door", "friendly_name": "Garage Door"}}
            """, false, -30),
            ("homeassistant/light/bedroom/state", """
            {"state": "off", "attributes": {"brightness": 0, "friendly_name": "Bedroom Light"}}
            """, false, -35),
            ("homeassistant/sensor/outdoor/temperature", """
            {"state": "8.2", "attributes": {"unit_of_measurement": "\u{00B0}C", "friendly_name": "Outdoor Temperature", "device_class": "temperature"}}
            """, false, -40),
            ("homeassistant/binary_sensor/motion/hallway", """
            {"state": "on", "attributes": {"device_class": "motion", "friendly_name": "Hallway Motion"}}
            """, false, -42),
            ("homeassistant/climate/thermostat/target", """
            {"state": "21.0", "attributes": {"unit_of_measurement": "\u{00B0}C", "friendly_name": "Thermostat Target"}}
            """, true, -45),
            ("homeassistant/sensor/energy/daily", """
            {"state": "12.4", "attributes": {"unit_of_measurement": "kWh", "friendly_name": "Daily Energy", "device_class": "energy"}}
            """, false, -50),
        ]

        return msgs.map { topic, payload, retained, offset in
            MQTTMessage(
                topic: topic,
                payloadString: payload.trimmingCharacters(in: .whitespacesAndNewlines),
                qos: .atMostOnce,
                retained: retained,
                timestamp: referenceDate.addingTimeInterval(Double(offset))
            )
        }
    }

    // MARK: - Publish Tabs

    static let publishTabs: [PublishTab] = [
        PublishTab(
            name: "Set Temperature",
            topic: "homeassistant/climate/thermostat/set",
            payload: """
            {
              "temperature": 22.0,
              "hvac_mode": "heat"
            }
            """,
            payloadFormat: .json,
            qos: .atLeastOnce,
            retain: false
        ),
        PublishTab(
            name: "Toggle Light",
            topic: "homeassistant/light/kitchen/set",
            payload: """
            {
              "state": "on",
              "brightness": 255,
              "color_temp": 350
            }
            """,
            payloadFormat: .json,
            qos: .atMostOnce,
            retain: false
        ),
        PublishTab(
            name: "Sensor Reset",
            topic: "homeassistant/sensor/reset",
            payload: "reset",
            payloadFormat: .text,
            qos: .exactlyOnce,
            retain: false
        ),
    ]

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

    // MARK: - Session Store Factory

    @MainActor
    static func makeSessionStore() -> SessionStore {
        let store = SessionStore(connection: activeConnection)
        store.isConnected = true
        store.connectedSince = Date().addingTimeInterval(-3725)
        store.subscriptions = subscriptions

        let msgs = messages()
        for message in msgs {
            store.topicTree.addMessage(message)
        }
        // Set messages directly (bypass persistence)
        store.messages = msgs

        store.publishTabs = publishTabs
        store.activePublishTabId = publishTabs.first?.id

        return store
    }

    // MARK: - Connection Store Factory

    @MainActor
    static func makeConnectionStore() -> ConnectionStore {
        ConnectionStore.mock(connections: connections, folders: folders)
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
