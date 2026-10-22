import Testing
@testable import MQTee

@Suite("MQTTConnectionConfigError")
struct MQTTConnectionConfigErrorTests {
    @Test func acceptsBoundaryValues() throws {
        let ranges = try MQTTConnectionConfigError.validate(port: 65535, keepAlive: 0, sessionExpiry: 4_294_967_295)
        #expect(ranges.port == 65535)
        #expect(ranges.keepAlive == 0)
        #expect(ranges.sessionExpiry == 4_294_967_295)
    }

    @Test func rejectsOutOfRangePort() {
        #expect(throws: MQTTConnectionConfigError.portOutOfRange(65536)) {
            try MQTTConnectionConfigError.validate(port: 65536, keepAlive: 60, sessionExpiry: nil)
        }
        #expect(throws: MQTTConnectionConfigError.portOutOfRange(0)) {
            try MQTTConnectionConfigError.validate(port: 0, keepAlive: 60, sessionExpiry: nil)
        }
    }

    @Test func rejectsNegativeKeepAlive() {
        #expect(throws: MQTTConnectionConfigError.keepAliveOutOfRange(-1)) {
            try MQTTConnectionConfigError.validate(port: 1883, keepAlive: -1, sessionExpiry: nil)
        }
    }

    @Test func rejectsOversizedSessionExpiry() {
        #expect(throws: MQTTConnectionConfigError.sessionExpiryOutOfRange(4_294_967_296)) {
            try MQTTConnectionConfigError.validate(port: 1883, keepAlive: 60, sessionExpiry: 4_294_967_296)
        }
    }

    @Test func textFieldsFallBackToDefaultsWhenEmpty() throws {
        let ranges = try MQTTConnectionConfigError.validate(port: " ", keepAlive: "", sessionExpiry: "")
        #expect(ranges.port == 1883)
        #expect(ranges.keepAlive == 60)
        #expect(ranges.sessionExpiry == nil)
    }

    @Test func textFieldsRejectNonNumericAndOutOfRangeInput() {
        #expect(throws: MQTTConnectionConfigError.notANumber("abc")) {
            try MQTTConnectionConfigError.validate(port: "abc", keepAlive: "60", sessionExpiry: "")
        }
        #expect(throws: MQTTConnectionConfigError.keepAliveOutOfRange(70000)) {
            try MQTTConnectionConfigError.validate(port: "1883", keepAlive: "70000", sessionExpiry: "")
        }
        #expect(throws: MQTTConnectionConfigError.sessionExpiryOutOfRange(-1)) {
            try MQTTConnectionConfigError.validate(port: "1883", keepAlive: "60", sessionExpiry: "-1")
        }
    }
}
