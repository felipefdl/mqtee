import Foundation

/// Re-indents JSON text without re-encoding it: string and number tokens are copied verbatim,
/// so large integers and exotic escapes are never altered.
nonisolated struct JSONPrettyPrinter {
    static func prettyPrint(_ input: String, indent: Int = 4) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var writer = Writer(bytes: Array(trimmed.utf8), indent: max(indent, 0))
        guard writer.writeValue(depth: 0) else { return nil }
        writer.skipWhitespace()
        guard writer.position == writer.bytes.count else { return nil }
        return String(bytes: writer.output, encoding: .utf8)
    }

    private struct Writer {
        static let maxDepth = 512

        let bytes: [UInt8]
        let indent: Int
        var position = 0
        var output: [UInt8] = []

        init(bytes: [UInt8], indent: Int) {
            self.bytes = bytes
            self.indent = indent
            output.reserveCapacity(bytes.count * 2)
        }

        mutating func skipWhitespace() {
            while position < bytes.count {
                switch bytes[position] {
                case 0x20, 0x09, 0x0A, 0x0D: position += 1
                default: return
                }
            }
        }

        private mutating func newline(depth: Int) {
            guard indent > 0 else { return }
            output.append(0x0A)
            output.append(contentsOf: repeatElement(0x20, count: depth * indent))
        }

        private mutating func consume(_ byte: UInt8) -> Bool {
            guard position < bytes.count, bytes[position] == byte else { return false }
            position += 1
            return true
        }

        mutating func writeValue(depth: Int) -> Bool {
            guard depth <= Self.maxDepth else { return false }
            skipWhitespace()
            guard position < bytes.count else { return false }
            switch bytes[position] {
            case UInt8(ascii: "{"): return writeContainer(open: "{", close: "}", depth: depth)
            case UInt8(ascii: "["): return writeContainer(open: "[", close: "]", depth: depth)
            case UInt8(ascii: "\""): return writeString()
            case UInt8(ascii: "t"): return writeLiteral("true")
            case UInt8(ascii: "f"): return writeLiteral("false")
            case UInt8(ascii: "n"): return writeLiteral("null")
            default: return writeNumber()
            }
        }

        private mutating func writeContainer(open: Character, close: Character, depth: Int) -> Bool {
            let isObject = open == "{"
            let closeByte = close.asciiValue!
            output.append(open.asciiValue!)
            position += 1
            skipWhitespace()
            if consume(closeByte) {
                output.append(closeByte)
                return true
            }

            while true {
                newline(depth: depth + 1)
                skipWhitespace()
                if isObject {
                    guard position < bytes.count, bytes[position] == UInt8(ascii: "\""), writeString() else {
                        return false
                    }
                    skipWhitespace()
                    guard consume(UInt8(ascii: ":")) else { return false }
                    output.append(UInt8(ascii: ":"))
                    if indent > 0 { output.append(0x20) }
                }
                guard writeValue(depth: depth + 1) else { return false }
                skipWhitespace()
                if consume(UInt8(ascii: ",")) {
                    output.append(UInt8(ascii: ","))
                } else if consume(closeByte) {
                    newline(depth: depth)
                    output.append(closeByte)
                    return true
                } else {
                    return false
                }
            }
        }

        private mutating func writeString() -> Bool {
            let start = position
            position += 1
            while position < bytes.count {
                let byte = bytes[position]
                switch byte {
                case UInt8(ascii: "\""):
                    position += 1
                    output.append(contentsOf: bytes[start..<position])
                    return true
                case UInt8(ascii: "\\"):
                    guard position + 1 < bytes.count else { return false }
                    switch bytes[position + 1] {
                    case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"), UInt8(ascii: "b"),
                         UInt8(ascii: "f"), UInt8(ascii: "n"), UInt8(ascii: "r"), UInt8(ascii: "t"):
                        position += 2
                    case UInt8(ascii: "u"):
                        guard position + 5 < bytes.count,
                              bytes[(position + 2)...(position + 5)].allSatisfy(Self.isHexDigit) else { return false }
                        position += 6
                    default:
                        return false
                    }
                case 0..<0x20:
                    return false
                default:
                    position += 1
                }
            }
            return false
        }

        private mutating func writeLiteral(_ literal: StaticString) -> Bool {
            let count = literal.utf8CodeUnitCount
            guard position + count <= bytes.count else { return false }
            let matches = literal.withUTF8Buffer { buffer in
                bytes[position..<(position + count)].elementsEqual(buffer)
            }
            guard matches else { return false }
            output.append(contentsOf: bytes[position..<(position + count)])
            position += count
            return true
        }

        private mutating func writeNumber() -> Bool {
            let start = position
            _ = consume(UInt8(ascii: "-"))
            guard position < bytes.count, Self.isDigit(bytes[position]) else { return false }
            if bytes[position] == UInt8(ascii: "0") {
                position += 1
            } else {
                skipDigits()
            }
            if consume(UInt8(ascii: ".")) {
                guard position < bytes.count, Self.isDigit(bytes[position]) else { return false }
                skipDigits()
            }
            if position < bytes.count, bytes[position] == UInt8(ascii: "e") || bytes[position] == UInt8(ascii: "E") {
                position += 1
                if position < bytes.count,
                   bytes[position] == UInt8(ascii: "+") || bytes[position] == UInt8(ascii: "-") {
                    position += 1
                }
                guard position < bytes.count, Self.isDigit(bytes[position]) else { return false }
                skipDigits()
            }
            output.append(contentsOf: bytes[start..<position])
            return true
        }

        private mutating func skipDigits() {
            while position < bytes.count, Self.isDigit(bytes[position]) { position += 1 }
        }

        private static func isDigit(_ byte: UInt8) -> Bool {
            byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
        }

        private static func isHexDigit(_ byte: UInt8) -> Bool {
            isDigit(byte)
                || (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "f"))
                || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "F"))
        }
    }
}
