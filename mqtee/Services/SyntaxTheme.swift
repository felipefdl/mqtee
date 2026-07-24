import SwiftUI

enum JSONToken {
    case key
    case stringValue
    case numberValue
    case booleanValue
    case nullValue
    case punctuation
}

enum XMLToken {
    case tagName
    case attributeName
    case attributeValue
    case text
    case comment
    case punctuation
}

struct SyntaxTheme {
    let colorScheme: ColorScheme

    func color(for token: JSONToken) -> Color {
        switch (token, colorScheme) {
        case (.key, .dark):          return Color(red: 0.51, green: 0.75, blue: 0.82)
        case (.key, _):              return Color(red: 0.44, green: 0.26, blue: 0.58)
        case (.stringValue, .dark):  return Color(red: 0.99, green: 0.42, blue: 0.35)
        case (.stringValue, _):      return Color(red: 0.77, green: 0.10, blue: 0.09)
        case (.numberValue, .dark):  return Color(red: 0.82, green: 0.75, blue: 0.50)
        case (.numberValue, _):      return Color(red: 0.11, green: 0.00, blue: 0.81)
        case (.booleanValue, .dark): return Color(red: 0.99, green: 0.42, blue: 0.62)
        case (.booleanValue, _):     return Color(red: 0.72, green: 0.21, blue: 0.62)
        case (.nullValue, .dark):    return Color(red: 0.99, green: 0.42, blue: 0.62)
        case (.nullValue, _):        return Color(red: 0.72, green: 0.21, blue: 0.62)
        case (.punctuation, _):      return .secondary
        }
    }

    func xmlColor(for token: XMLToken) -> Color {
        switch (token, colorScheme) {
        case (.tagName, .dark):        return Color(red: 0.51, green: 0.75, blue: 0.82)
        case (.tagName, _):            return Color(red: 0.44, green: 0.26, blue: 0.58)
        case (.attributeName, .dark):  return Color(red: 0.82, green: 0.75, blue: 0.50)
        case (.attributeName, _):      return Color(red: 0.11, green: 0.00, blue: 0.81)
        case (.attributeValue, .dark): return Color(red: 0.99, green: 0.42, blue: 0.35)
        case (.attributeValue, _):     return Color(red: 0.77, green: 0.10, blue: 0.09)
        case (.comment, .dark):        return Color(red: 0.55, green: 0.55, blue: 0.55)
        case (.comment, _):           return Color(red: 0.45, green: 0.45, blue: 0.45)
        case (.text, _):               return .primary
        case (.punctuation, _):        return .secondary
        }
    }
}
