import SwiftUI

extension PublishPanelContent {
    @ViewBuilder
    var payloadEditor: some View {
        let theme = SyntaxTheme(colorScheme: colorScheme)
        switch payloadFormat {
        case .json:
            HighlightedTextEditor(
                text: $payload,
                highlight: { JSONHighlighter.highlight($0, theme: theme) },
                validate: Self.validateJSON
            )
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button { prettifyJSON() } label: {
                    Image(systemName: "curlybraces")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(!jsonIsValid)
                .help("Prettify JSON")
                .padding(8)
            }
        case .hex:
            CodeEditor(text: $payload)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottomLeading) {
                    hexValidationBadge.padding(8)
                }
        case .base64:
            CodeEditor(text: $payload)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottomLeading) {
                    base64ValidationBadge.padding(8)
                }
        case .xml:
            HighlightedTextEditor(
                text: $payload,
                highlight: { XMLHighlighter.highlight($0, theme: theme) },
                validate: Self.validateXMLText
            )
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button { prettifyXML() } label: {
                    Image(systemName: "curlybraces")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(!xmlIsValid)
                .help("Prettify XML")
                .padding(8)
            }
        case .text:
            CodeEditor(text: $payload)
                .frame(maxHeight: .infinity)
        }
    }

    private static func validateJSON(_ text: String) -> ValidationResult? {
        guard let data = text.data(using: .utf8) else { return nil }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return nil
        } catch let error as NSError {
            let debug = error.userInfo[NSDebugDescriptionErrorKey] as? String
            let message = debug ?? error.localizedDescription
            var line: Int?
            if let debug, let lineRange = debug.range(of: "line ") {
                let digits = debug[lineRange.upperBound...].prefix(while: \.isNumber)
                line = Int(digits)
            }
            return ValidationResult(line: line, message: message)
        }
    }

    private static func validateXMLText(_ text: String) -> ValidationResult? {
        guard let data = text.data(using: .utf8) else { return nil }
        let parser = XMLParser(data: data)
        let delegate = XMLValidationDelegate()
        parser.delegate = delegate
        if parser.parse() { return nil }
        let message = parser.parserError?.localizedDescription ?? "Invalid XML"
        let line = parser.lineNumber > 0 ? parser.lineNumber : nil
        return ValidationResult(line: line, message: message)
    }
}
