import Testing
import Foundation
@testable import MQTee

@Suite("PublishTab")
struct PublishTabTests {

    @Test("displayName with explicit name returns that name")
    func displayNameWithExplicitName() {
        let tab = PublishTab(name: "My Tab", topic: "sensor/temp")
        #expect(tab.displayName == "My Tab")
    }

    @Test("displayName with no name but topic returns topic")
    func displayNameWithTopicOnly() {
        let tab = PublishTab(topic: "sensor/temp")
        #expect(tab.displayName == "sensor/temp")
    }

    @Test("displayName with neither name nor topic returns Untitled")
    func displayNameWithNeither() {
        let tab = PublishTab()
        #expect(tab.displayName == String(localized: "Untitled", comment: "Default publish tab name"))
    }

    @Test("displayName with empty name and empty topic returns Untitled")
    func displayNameWithEmptyBoth() {
        let tab = PublishTab(name: "", topic: "")
        #expect(tab.displayName == String(localized: "Untitled", comment: "Default publish tab name"))
    }

    @Test("Default values are applied correctly")
    func defaultValues() {
        let tab = PublishTab()
        #expect(tab.name == nil)
        #expect(tab.topic == "")
        #expect(tab.payload == "")
        #expect(tab.payloadFormat == .text)
        #expect(tab.qos == .atMostOnce)
        #expect(tab.retain == false)
    }
}

@Suite("PersistedPublishTabs")
struct PersistedPublishTabsTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let connId = UUID()
        let tab = PublishTab(name: "Test", topic: "t/1", payload: "hello", qos: .atLeastOnce, retain: true)
        let original = PersistedPublishTabs(connectionId: connId, tabs: [tab], activeTabId: tab.id)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistedPublishTabs.self, from: data)

        #expect(decoded.connectionId == connId)
        #expect(decoded.tabs.count == 1)
        #expect(decoded.tabs.first?.name == "Test")
        #expect(decoded.tabs.first?.topic == "t/1")
        #expect(decoded.tabs.first?.payload == "hello")
        #expect(decoded.tabs.first?.qos == .atLeastOnce)
        #expect(decoded.tabs.first?.retain == true)
        #expect(decoded.activeTabId == tab.id)
    }

    @Test("Default values")
    func defaultValues() {
        let connId = UUID()
        let persisted = PersistedPublishTabs(connectionId: connId)
        #expect(persisted.tabs.isEmpty)
        #expect(persisted.activeTabId == nil)
    }
}

@Suite("PublishPayloadFormat")
struct PublishPayloadFormatTests {

    @Test("localizedName matches rawValue")
    func localizedNameMatchesRawValue() {
        for format in PublishPayloadFormat.allCases {
            #expect(format.localizedName == format.rawValue)
        }
    }

    @Test("systemImage returns non-empty string")
    func systemImageNonEmpty() {
        for format in PublishPayloadFormat.allCases {
            #expect(!format.systemImage.isEmpty)
        }
    }

    @Test("base64 systemImage")
    func base64SystemImage() {
        #expect(PublishPayloadFormat.base64.systemImage == "arrow.up.arrow.down")
    }

    @Test("xml systemImage")
    func xmlSystemImage() {
        #expect(PublishPayloadFormat.xml.systemImage == "chevron.left.forwardslash.chevron.right")
    }

    @Test("Codable round-trip with base64 format")
    func codableRoundTripBase64() throws {
        let tab = PublishTab(topic: "test", payload: "SGVsbG8=", payloadFormat: .base64)
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(PublishTab.self, from: data)
        #expect(decoded.payloadFormat == .base64)
        #expect(decoded.payload == "SGVsbG8=")
    }

    @Test("Codable round-trip with xml format")
    func codableRoundTripXml() throws {
        let tab = PublishTab(topic: "test", payload: "<root/>", payloadFormat: .xml)
        let data = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(PublishTab.self, from: data)
        #expect(decoded.payloadFormat == .xml)
        #expect(decoded.payload == "<root/>")
    }

    @Test("Decoding without payloadFormat field defaults to text")
    func decodingMissingFormatDefaultsToText() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","topic":"t","payload":"p","qos":0,"retain":false,"createdAt":0,"lastModified":0}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let tab = try decoder.decode(PublishTab.self, from: Data(json.utf8))
        #expect(tab.payloadFormat == .text)
    }
}
