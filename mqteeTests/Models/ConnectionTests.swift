import Testing
import Foundation
@testable import MQTee

@Suite("Connection")
struct ConnectionTests {

    @Test("subtitle with username includes user@host:port")
    func subtitleWithUsername() {
        let conn = Connection(name: "Test", host: "broker.local", port: 1883, username: "user")
        #expect(conn.subtitle == "user@broker.local:1883")
    }

    @Test("subtitle without username returns host:port")
    func subtitleWithoutUsername() {
        let conn = Connection(name: "Test", host: "broker.local", port: 1883)
        #expect(conn.subtitle == "broker.local:1883")
    }

    @Test("subtitle with empty username returns host:port")
    func subtitleWithEmptyUsername() {
        let conn = Connection(name: "Test", host: "broker.local", port: 1883, username: "")
        #expect(conn.subtitle == "broker.local:1883")
    }

    @Test("Empty clientId generates mqtee- prefixed ID")
    func emptyClientIdGeneratesPrefix() {
        let conn = Connection(name: "Test", host: "broker.local")
        #expect(conn.clientId.hasPrefix("mqtee-"))
        #expect(conn.clientId.count > 6)
    }

    @Test("Explicit clientId preserved as-is")
    func explicitClientIdPreserved() {
        let conn = Connection(name: "Test", host: "broker.local", clientId: "my-client")
        #expect(conn.clientId == "my-client")
    }

    @Test("Default values are applied correctly")
    func defaultValues() {
        let conn = Connection(name: "Test", host: "broker.local")
        #expect(conn.port == 1883)
        #expect(conn.mqttVersion == .v311)
        #expect(conn.cleanSession == true)
        #expect(conn.keepAlive == 60)
        #expect(conn.useTLS == false)
        #expect(conn.useClientCertificate == false)
        #expect(conn.allowInsecureTLS == false)
        #expect(conn.persistSession == true)
    }
}

@Suite("MQTTVersion")
struct MQTTVersionTests {

    @Test("displayName contains version string")
    func displayName() {
        #expect(MQTTVersion.v311.displayName == "MQTT 3.1.1")
        #expect(MQTTVersion.v5.displayName == "MQTT 5.0")
    }
}

@Suite("QoSLevel")
struct QoSLevelTests {

    @Test("displayName contains expected strings")
    func displayName() {
        #expect(QoSLevel.atMostOnce.displayName.contains("At most once"))
        #expect(QoSLevel.atLeastOnce.displayName.contains("At least once"))
        #expect(QoSLevel.exactlyOnce.displayName.contains("Exactly once"))
    }

    @Test("shortName returns QoS N format")
    func shortName() {
        #expect(QoSLevel.atMostOnce.shortName == "QoS 0")
        #expect(QoSLevel.atLeastOnce.shortName == "QoS 1")
        #expect(QoSLevel.exactlyOnce.shortName == "QoS 2")
    }

    @Test("rawValue matches integer values")
    func rawValue() {
        #expect(QoSLevel.atMostOnce.rawValue == 0)
        #expect(QoSLevel.atLeastOnce.rawValue == 1)
        #expect(QoSLevel.exactlyOnce.rawValue == 2)
    }
}

@Suite("LastWillSettings")
struct LastWillSettingsTests {

    @Test("Default values")
    func defaultValues() {
        let lw = LastWillSettings()
        #expect(lw.enabled == false)
        #expect(lw.topic == "")
        #expect(lw.message == "")
        #expect(lw.qos == .atMostOnce)
        #expect(lw.retain == false)
    }
}
