import Testing
import Foundation
@testable import MQTee

@Suite("LicenseEntry")
struct LicenseEntryTests {

    @Test("reflowed joins hard-wrapped plain paragraphs")
    func reflowJoinsPlainParagraph() {
        let text = "Permission is hereby granted,\nfree of charge, to any\nperson obtaining a copy."
        let expected = "Permission is hereby granted, free of charge, to any person obtaining a copy."
        #expect(LicenseEntry.reflowed(text) == expected)
    }

    @Test("reflowed keeps paragraph separation")
    func reflowKeepsParagraphs() {
        let text = "First line\nsecond line\n\nNext paragraph\nwraps."
        #expect(LicenseEntry.reflowed(text) == "First line second line\n\nNext paragraph wraps.")
    }

    @Test("reflowed leaves indented and list paragraphs untouched")
    func reflowKeepsStructuredParagraphs() {
        let indented = "Header\n    indented body\n    more"
        let list = "Terms:\n1. first\n2. second"
        let bullets = "Items\n- one\n- two"
        #expect(LicenseEntry.reflowed(indented) == indented)
        #expect(LicenseEntry.reflowed(list) == list)
        #expect(LicenseEntry.reflowed(bullets) == bullets)
    }

    @Test("reflowed normalizes CRLF")
    func reflowNormalizesCRLF() {
        #expect(LicenseEntry.reflowed("a\r\nb") == "a b")
    }
}
