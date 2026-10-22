import SwiftUI
import Testing
@testable import MQTee

@Suite("JSONHighlighter")
@MainActor
struct JSONHighlighterTests {

    @Test("partial input ending inside an escape keeps every character", arguments: [
        "\"a\\",
        "{\"s\": \"a{b\\",
        "\\",
        "\""
    ])
    func trailingEscapeInsideString(input: String) {
        let highlighted = JSONHighlighter.highlight(input, theme: SyntaxTheme(colorScheme: .light))
        #expect(String(highlighted.characters) == input)
    }
}
