import Foundation

enum PayloadContentType: String {
    case json = "JSON"
    case xml = "XML"
    case plainText = "Plain Text"
    case binary = "Binary"

    var localizedName: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .json: return "curlybraces"
        case .xml: return "chevron.left.forwardslash.chevron.right"
        case .plainText: return "text.alignleft"
        case .binary: return "01.square"
        }
    }

    static func detect(from data: Data) -> PayloadContentType {
        guard let string = String(data: data, encoding: .utf8) else {
            return .binary
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plainText }

        // JSON detection: check structural prefix/suffix, validate with JSONSerialization
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if (try? JSONSerialization.jsonObject(with: data)) != nil {
                return .json
            }
        }

        // XML detection: starts with < and contains a closing tag
        if trimmed.hasPrefix("<") && trimmed.contains("</") {
            return .xml
        }

        return .plainText
    }
}
