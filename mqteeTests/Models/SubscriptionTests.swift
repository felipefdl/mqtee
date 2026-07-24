import Testing
import Foundation
@testable import MQTee

@Suite("Subscription")
struct SubscriptionTests {

    // MARK: - Default values

    @Test("Default values are MQTT 3.1.1 compatible")
    func defaultValues() {
        let sub = Subscription(topic: "test/topic")

        #expect(sub.qos == .atMostOnce)
        #expect(sub.noLocal == false)
        #expect(sub.retainAsPublished == false)
        #expect(sub.retainHandling == .sendOnSubscribe)
        #expect(sub.color == .blue)
    }

    // MARK: - MQTT 5 options

    @Test("MQTT 5 subscription options can be set")
    func mqttV5Options() {
        let sub = Subscription(
            topic: "sensor/#",
            qos: .exactlyOnce,
            noLocal: true,
            retainAsPublished: true,
            retainHandling: .doNotSend
        )

        #expect(sub.noLocal == true)
        #expect(sub.retainAsPublished == true)
        #expect(sub.retainHandling == .doNotSend)
        #expect(sub.qos == .exactlyOnce)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves all fields including v5 options")
    func codableRoundTrip() throws {
        let original = Subscription(
            topic: "home/+/temperature",
            qos: .atLeastOnce,
            color: .green,
            noLocal: true,
            retainAsPublished: true,
            retainHandling: .sendOnNewSubscribe
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Subscription.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.topic == original.topic)
        #expect(decoded.qos == original.qos)
        #expect(decoded.color == original.color)
        #expect(decoded.noLocal == original.noLocal)
        #expect(decoded.retainAsPublished == original.retainAsPublished)
        #expect(decoded.retainHandling == original.retainHandling)
    }
}

@Suite("RetainHandling")
struct RetainHandlingTests {

    @Test("Raw values match MQTT 5 spec")
    func rawValues() {
        #expect(RetainHandling.sendOnSubscribe.rawValue == 0)
        #expect(RetainHandling.sendOnNewSubscribe.rawValue == 1)
        #expect(RetainHandling.doNotSend.rawValue == 2)
    }

    @Test("All cases are present")
    func allCases() {
        #expect(RetainHandling.allCases.count == 3)
    }
}
