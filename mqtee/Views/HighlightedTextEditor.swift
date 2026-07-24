import SwiftUI

struct ValidationResult {
    let line: Int?
    let message: String
}

struct HighlightedTextEditor: View {
    @Binding var text: String
    var highlight: (String) -> AttributedString
    var validate: ((String) -> ValidationResult?)? = nil

    @State private var validation: ValidationResult?
    @State private var validationTask: Task<Void, Never>?

    var body: some View {
        TextEditor(text: Binding(
            get: {
                var result = highlight(text)
                if let errorLine = validation?.line {
                    Self.highlightErrorLine(errorLine, in: &result, text: text)
                }
                return result
            },
            set: { text = String($0.characters) }
        ))
        .font(.system(.body, design: .monospaced))
        .scrollContentBackground(.hidden)
        .frame(minHeight: 100)
        .background(.fill.tertiary, in: .rect(cornerRadius: 8))
        .overlay(alignment: .bottomLeading) {
            if let message = validation?.message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: .capsule)
                    .padding(6)
            }
        }
        .onChange(of: text, initial: true) { _, newText in
            scheduleValidation(newText)
        }
        .onDisappear { validationTask?.cancel() }
    }

    private func scheduleValidation(_ text: String) {
        validationTask?.cancel()
        guard let validate, !text.isEmpty else {
            validation = nil
            return
        }
        validationTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            validation = validate(text)
        }
    }

    private static func highlightErrorLine(_ errorLine: Int, in attributed: inout AttributedString, text: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard errorLine >= 1, errorLine <= lines.count else { return }

        var charOffset = 0
        for i in 0..<(errorLine - 1) {
            charOffset += lines[i].count + 1
        }
        let lineLength = lines[errorLine - 1].count

        guard lineLength > 0 else { return }
        let start = attributed.index(attributed.startIndex, offsetByCharacters: charOffset)
        let end = attributed.index(start, offsetByCharacters: lineLength)
        attributed[start..<end].backgroundColor = Color.red.opacity(0.15)
    }
}
