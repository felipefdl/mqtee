import SwiftUI

struct JSONHighlighter {
    private static let maxHighlightSize = 100_000  // 100KB guard

    static func highlight(_ jsonString: String, theme: SyntaxTheme) -> AttributedString {
        let monoFont = Font.system(.body, design: .monospaced)

        guard jsonString.utf8.count <= maxHighlightSize else {
            var plain = AttributedString(jsonString)
            plain.font = monoFont
            return plain
        }

        var result = AttributedString()
        let chars = Array(jsonString)
        let count = chars.count
        var i = 0

        while i < count {
            let ch = chars[i]

            switch ch {
            case "\"":
                let stringStart = i
                i += 1
                // Walk to end of quoted string, handling escapes
                while i < count && chars[i] != "\"" {
                    if chars[i] == "\\" { i += 1 }  // skip escaped char
                    i += 1
                }
                if i < count { i += 1 }  // consume closing quote

                let stringContent = String(chars[stringStart..<i])
                let token = isKey(chars: chars, from: i, count: count) ? JSONToken.key : JSONToken.stringValue
                var segment = AttributedString(stringContent)
                segment.font = monoFont
                segment.foregroundColor = theme.color(for: token)
                result.append(segment)

            case "-", "0"..."9":
                let numStart = i
                i = consumeNumber(chars: chars, from: i, count: count)
                let numContent = String(chars[numStart..<i])
                var segment = AttributedString(numContent)
                segment.font = monoFont
                segment.foregroundColor = theme.color(for: .numberValue)
                result.append(segment)

            case "t", "f":
                if matchesLiteral(chars: chars, from: i, count: count, literal: "true") {
                    var segment = AttributedString("true")
                    segment.font = monoFont
                    segment.foregroundColor = theme.color(for: .booleanValue)
                    result.append(segment)
                    i += 4
                } else if matchesLiteral(chars: chars, from: i, count: count, literal: "false") {
                    var segment = AttributedString("false")
                    segment.font = monoFont
                    segment.foregroundColor = theme.color(for: .booleanValue)
                    result.append(segment)
                    i += 5
                } else {
                    var segment = AttributedString(String(ch))
                    segment.font = monoFont
                    result.append(segment)
                    i += 1
                }

            case "n":
                if matchesLiteral(chars: chars, from: i, count: count, literal: "null") {
                    var segment = AttributedString("null")
                    segment.font = monoFont
                    segment.foregroundColor = theme.color(for: .nullValue)
                    result.append(segment)
                    i += 4
                } else {
                    var segment = AttributedString(String(ch))
                    segment.font = monoFont
                    result.append(segment)
                    i += 1
                }

            case "{", "}", "[", "]", ",", ":":
                var segment = AttributedString(String(ch))
                segment.font = monoFont
                segment.foregroundColor = theme.color(for: .punctuation)
                result.append(segment)
                i += 1

            default:
                // Whitespace and anything else -- no color
                var segment = AttributedString(String(ch))
                segment.font = monoFont
                result.append(segment)
                i += 1
            }
        }

        return result
    }

    // MARK: - Helpers

    /// Determines if a just-parsed string is a key by looking ahead for a colon.
    private static func isKey(chars: [Character], from index: Int, count: Int) -> Bool {
        var j = index
        while j < count {
            let c = chars[j]
            if c == ":" { return true }
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                j += 1
                continue
            }
            return false
        }
        return false
    }

    /// Consumes a JSON number (integer, float, negative, scientific notation).
    private static func consumeNumber(chars: [Character], from start: Int, count: Int) -> Int {
        var i = start
        if i < count && chars[i] == "-" { i += 1 }
        while i < count && chars[i] >= "0" && chars[i] <= "9" { i += 1 }
        if i < count && chars[i] == "." {
            i += 1
            while i < count && chars[i] >= "0" && chars[i] <= "9" { i += 1 }
        }
        if i < count && (chars[i] == "e" || chars[i] == "E") {
            i += 1
            if i < count && (chars[i] == "+" || chars[i] == "-") { i += 1 }
            while i < count && chars[i] >= "0" && chars[i] <= "9" { i += 1 }
        }
        return i
    }

    /// Checks if the characters starting at `from` match the given literal exactly.
    private static func matchesLiteral(chars: [Character], from: Int, count: Int, literal: String) -> Bool {
        let literalChars = Array(literal)
        guard from + literalChars.count <= count else { return false }
        for (offset, lc) in literalChars.enumerated() {
            if chars[from + offset] != lc { return false }
        }
        return true
    }
}
