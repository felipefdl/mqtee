import SwiftUI

extension PublishPanelContent {
    func scheduleValidation() {
        validationTask?.cancel()
        validationTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            switch payloadFormat {
            case .json: validateJSON()
            case .hex: validateHex()
            case .base64: validateBase64()
            case .xml: validateXML()
            case .text: break
            }
        }
    }

    func clearAllValidation() {
        jsonIsValid = true
        jsonError = nil
        hexIsValid = true
        hexError = nil
        base64IsValid = true
        base64Error = nil
        xmlIsValid = true
        xmlError = nil
    }

    func validateJSON() {
        guard payloadFormat == .json else {
            jsonIsValid = true
            jsonError = nil
            return
        }
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            jsonIsValid = true
            jsonError = nil
            return
        }
        guard let data = payload.data(using: .utf8) else {
            jsonIsValid = false
            jsonError = "Invalid UTF-8"
            return
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            jsonIsValid = true
            jsonError = nil
        } catch {
            jsonIsValid = false
            jsonError = error.localizedDescription
        }
    }

    var jsonValidationBadge: some View {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let showBadge = !trimmed.isEmpty
        return Group {
            if showBadge && jsonIsValid {
                Label("Valid JSON", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Invalid JSON", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .help(jsonError ?? "Invalid JSON")
                    .opacity(showBadge ? 1 : 0)
            }
        }
        .font(.caption)
    }

    func prettifyJSON() {
        guard let pretty = JSONPrettyPrinter.prettyPrint(payload) else { return }
        payload = pretty
    }

    func validateHex() {
        guard payloadFormat == .hex else {
            hexIsValid = true
            hexError = nil
            return
        }
        let stripped = payload.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        guard !stripped.isEmpty else {
            hexIsValid = true
            hexError = nil
            return
        }
        let hexCharSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if !stripped.unicodeScalars.allSatisfy({ hexCharSet.contains($0) }) {
            hexIsValid = false
            hexError = "Contains non-hex characters"
            return
        }
        if stripped.count % 2 != 0 {
            hexIsValid = false
            hexError = "Odd number of hex characters"
            return
        }
        hexIsValid = true
        hexError = nil
    }

    var hexValidationBadge: some View {
        let stripped = payload.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        return Group {
            if !stripped.isEmpty {
                if hexIsValid {
                    Label("Valid Hex", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(hexError ?? "Invalid Hex", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .help(hexError ?? "Invalid Hex")
                }
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: .capsule)
    }

    func dataFromHexString(_ hex: String) -> Data? {
        let stripped = hex.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        guard stripped.count % 2 == 0 else { return nil }
        var data = Data(capacity: stripped.count / 2)
        var index = stripped.startIndex
        while index < stripped.endIndex {
            let nextIndex = stripped.index(index, offsetBy: 2)
            guard let byte = UInt8(stripped[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    func formatHex() {
        let stripped = payload.replacingOccurrences(of: "\\s", with: "", options: .regularExpression).uppercased()
        var formatted: [String] = []
        var index = stripped.startIndex
        while index < stripped.endIndex {
            let nextIndex = stripped.index(index, offsetBy: 2)
            formatted.append(String(stripped[index..<nextIndex]))
            index = nextIndex
        }
        payload = formatted.joined(separator: " ")
    }

    func validateBase64() {
        guard payloadFormat == .base64 else {
            base64IsValid = true
            base64Error = nil
            return
        }
        let stripped = payload.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        guard !stripped.isEmpty else {
            base64IsValid = true
            base64Error = nil
            return
        }
        if Data(base64Encoded: stripped) != nil {
            base64IsValid = true
            base64Error = nil
        } else {
            base64IsValid = false
            base64Error = "Invalid Base64 encoding"
        }
    }

    var base64ValidationBadge: some View {
        let stripped = payload.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        return Group {
            if !stripped.isEmpty {
                if base64IsValid {
                    Label("Valid Base64", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(base64Error ?? "Invalid Base64", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .help(base64Error ?? "Invalid Base64")
                }
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: .capsule)
    }

    func formatBase64() {
        let stripped = payload.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        guard let data = Data(base64Encoded: stripped) else { return }
        payload = data.base64EncodedString(options: [.lineLength76Characters, .endLineWithLineFeed])
    }

    func validateXML() {
        guard payloadFormat == .xml else {
            xmlIsValid = true
            xmlError = nil
            return
        }
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            xmlIsValid = true
            xmlError = nil
            return
        }
        guard let data = payload.data(using: .utf8) else {
            xmlIsValid = false
            xmlError = "Invalid UTF-8"
            return
        }
        let parser = XMLParser(data: data)
        let delegate = XMLValidationDelegate()
        parser.delegate = delegate
        if parser.parse() {
            xmlIsValid = true
            xmlError = nil
        } else {
            xmlIsValid = false
            xmlError = parser.parserError?.localizedDescription ?? "Invalid XML"
        }
    }

    var xmlValidationBadge: some View {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        return Group {
            if !trimmed.isEmpty {
                if xmlIsValid {
                    Label("Valid XML", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(xmlError ?? "Invalid XML", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .help(xmlError ?? "Invalid XML")
                }
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: .capsule)
    }

    func prettifyXML() {
        guard let data = payload.data(using: .utf8) else { return }
        let parser = XMLParser(data: data)
        let delegate = XMLPrettifyDelegate()
        parser.delegate = delegate
        guard parser.parse() else { return }
        payload = delegate.result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
