import SwiftUI

struct XMLHighlighter {
    private static let maxHighlightSize = 100_000

    static func highlight(_ xmlString: String, theme: SyntaxTheme) -> AttributedString {
        let monoFont = Font.system(.body, design: .monospaced)

        guard xmlString.utf8.count <= maxHighlightSize else {
            var plain = AttributedString(xmlString)
            plain.font = monoFont
            return plain
        }

        var result = AttributedString()
        let chars = Array(xmlString)
        let count = chars.count
        var i = 0

        while i < count {
            if chars[i] == "<" {
                if matchesPrefix(chars: chars, from: i, count: count, prefix: "<!--") {
                    i = consumeComment(chars: chars, from: i, count: count, font: monoFont, theme: theme, result: &result)
                } else if matchesPrefix(chars: chars, from: i, count: count, prefix: "<![CDATA[") {
                    i = consumeCDATA(chars: chars, from: i, count: count, font: monoFont, theme: theme, result: &result)
                } else {
                    i = consumeTag(chars: chars, from: i, count: count, font: monoFont, theme: theme, result: &result)
                }
            } else {
                let textStart = i
                while i < count && chars[i] != "<" { i += 1 }
                let content = String(chars[textStart..<i])
                var segment = AttributedString(content)
                segment.font = monoFont
                segment.foregroundColor = theme.xmlColor(for: .text)
                result.append(segment)
            }
        }

        return result
    }

    // MARK: - Comment <!-- ... -->

    private static func consumeComment(
        chars: [Character], from start: Int, count: Int,
        font: Font, theme: SyntaxTheme, result: inout AttributedString
    ) -> Int {
        var i = start
        while i < count {
            if matchesPrefix(chars: chars, from: i, count: count, prefix: "-->") {
                i += 3
                break
            }
            i += 1
        }
        let content = String(chars[start..<i])
        var segment = AttributedString(content)
        segment.font = font
        segment.foregroundColor = theme.xmlColor(for: .comment)
        result.append(segment)
        return i
    }

    // MARK: - CDATA <![CDATA[ ... ]]>

    private static func consumeCDATA(
        chars: [Character], from start: Int, count: Int,
        font: Font, theme: SyntaxTheme, result: inout AttributedString
    ) -> Int {
        var i = start
        while i < count {
            if matchesPrefix(chars: chars, from: i, count: count, prefix: "]]>") {
                i += 3
                break
            }
            i += 1
        }
        let content = String(chars[start..<i])
        var segment = AttributedString(content)
        segment.font = font
        segment.foregroundColor = theme.xmlColor(for: .text)
        result.append(segment)
        return i
    }

    // MARK: - Tag <name attr="val"> or </name> or <?...?>

    private static func consumeTag(
        chars: [Character], from start: Int, count: Int,
        font: Font, theme: SyntaxTheme, result: inout AttributedString
    ) -> Int {
        var i = start

        // Opening punctuation: < or </ or <?
        var punctLen = 1
        if i + 1 < count && chars[i + 1] == "/" { punctLen = 2 }
        else if i + 1 < count && chars[i + 1] == "?" { punctLen = 2 }
        appendSegment(String(chars[i..<(i + punctLen)]), color: theme.xmlColor(for: .punctuation), font: font, result: &result)
        i += punctLen

        // Tag name
        let nameStart = i
        while i < count && !isTagBreak(chars[i]) { i += 1 }
        if i > nameStart {
            appendSegment(String(chars[nameStart..<i]), color: theme.xmlColor(for: .tagName), font: font, result: &result)
        }

        // Attributes and closing
        while i < count {
            if chars[i] == ">" {
                appendSegment(">", color: theme.xmlColor(for: .punctuation), font: font, result: &result)
                i += 1
                break
            }
            if matchesPrefix(chars: chars, from: i, count: count, prefix: "/>") {
                appendSegment("/>", color: theme.xmlColor(for: .punctuation), font: font, result: &result)
                i += 2
                break
            }
            if matchesPrefix(chars: chars, from: i, count: count, prefix: "?>") {
                appendSegment("?>", color: theme.xmlColor(for: .punctuation), font: font, result: &result)
                i += 2
                break
            }

            // Whitespace
            if chars[i].isWhitespace {
                appendSegment(String(chars[i]), color: nil, font: font, result: &result)
                i += 1
                continue
            }

            // = sign
            if chars[i] == "=" {
                appendSegment("=", color: theme.xmlColor(for: .punctuation), font: font, result: &result)
                i += 1
                continue
            }

            // Quoted attribute value
            if chars[i] == "\"" || chars[i] == "'" {
                let quote = chars[i]
                let valStart = i
                i += 1
                while i < count && chars[i] != quote { i += 1 }
                if i < count { i += 1 }
                appendSegment(String(chars[valStart..<i]), color: theme.xmlColor(for: .attributeValue), font: font, result: &result)
                continue
            }

            // Attribute name (anything else before = or whitespace or >)
            let attrStart = i
            while i < count && !chars[i].isWhitespace && chars[i] != "=" && chars[i] != ">" && chars[i] != "/" { i += 1 }
            if i > attrStart {
                appendSegment(String(chars[attrStart..<i]), color: theme.xmlColor(for: .attributeName), font: font, result: &result)
            }
        }

        return i
    }

    // MARK: - Helpers

    private static func appendSegment(_ text: String, color: Color?, font: Font, result: inout AttributedString) {
        var segment = AttributedString(text)
        segment.font = font
        if let color { segment.foregroundColor = color }
        result.append(segment)
    }

    private static func isTagBreak(_ ch: Character) -> Bool {
        ch.isWhitespace || ch == ">" || ch == "/" || ch == "?"
    }

    private static func matchesPrefix(chars: [Character], from: Int, count: Int, prefix: String) -> Bool {
        let prefixChars = Array(prefix)
        guard from + prefixChars.count <= count else { return false }
        for (offset, pc) in prefixChars.enumerated() {
            if chars[from + offset] != pc { return false }
        }
        return true
    }
}
