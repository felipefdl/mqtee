import Testing
import Foundation
@testable import MQTee

@Suite("PayloadContentType.detect")
struct PayloadContentTypeTests {

    @Test("Non-UTF8 bytes return .binary")
    func nonUtf8ReturnsBinary() {
        let data = Data([0xFF, 0xFE, 0x00, 0x80])
        #expect(PayloadContentType.detect(from: data) == .binary)
    }

    @Test("Empty data returns .plainText")
    func emptyDataReturnsPlainText() {
        let data = Data()
        #expect(PayloadContentType.detect(from: data) == .plainText)
    }

    @Test("Empty string returns .plainText")
    func emptyStringReturnsPlainText() {
        let data = "".data(using: .utf8)!
        #expect(PayloadContentType.detect(from: data) == .plainText)
    }

    @Test("Whitespace-only string returns .plainText")
    func whitespaceOnlyReturnsPlainText() {
        let data = "   \n  ".data(using: .utf8)!
        #expect(PayloadContentType.detect(from: data) == .plainText)
    }

    @Test("Valid JSON object returns .json")
    func validJsonObjectReturnsJson() {
        let data = #"{"key":"val"}"#.data(using: .utf8)!
        #expect(PayloadContentType.detect(from: data) == .json)
    }

    @Test("Valid JSON array returns .json")
    func validJsonArrayReturnsJson() {
        let data = "[1,2,3]".data(using: .utf8)!
        #expect(PayloadContentType.detect(from: data) == .json)
    }

    @Test("JSON-like but invalid returns .plainText")
    func invalidJsonReturnsPlainText() {
        let data = "{bad}".data(using: .utf8)!
        #expect(PayloadContentType.detect(from: data) == .plainText)
    }

    @Test("Whitespace-padded JSON returns .json")
    func whitespacePaddedJsonReturnsJson() {
        let data = "  \n{\"key\": \"val\"}\n  ".data(using: .utf8)!
        #expect(PayloadContentType.detect(from: data) == .json)
    }

    @Test("XML with closing tag returns .xml")
    func xmlWithClosingTagReturnsXml() {
        let data = "<root></root>".data(using: .utf8)!
        #expect(PayloadContentType.detect(from: data) == .xml)
    }

    @Test("XML without closing tag returns .plainText")
    func xmlWithoutClosingTagReturnsPlainText() {
        let data = "<br>".data(using: .utf8)!
        #expect(PayloadContentType.detect(from: data) == .plainText)
    }

    @Test("Plain text returns .plainText")
    func plainTextReturnsPlainText() {
        let data = "hello world".data(using: .utf8)!
        #expect(PayloadContentType.detect(from: data) == .plainText)
    }

    @Test("localizedName matches rawValue")
    func localizedNameMatchesRawValue() {
        for contentType in [PayloadContentType.json, .xml, .plainText, .binary] {
            #expect(contentType.localizedName == contentType.rawValue)
        }
    }

    @Test("systemImage returns non-empty string for all cases")
    func systemImageReturnsNonEmpty() {
        for contentType in [PayloadContentType.json, .xml, .plainText, .binary] {
            #expect(!contentType.systemImage.isEmpty)
        }
    }
}
