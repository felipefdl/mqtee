import SwiftUI

struct Mqtt5PropertiesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var mqttContentType: String
    @Binding var responseTopic: String
    @Binding var correlationData: String
    @Binding var messageExpiryInterval: String
    @Binding var payloadFormatIndicator: PayloadFormatIndicatorOption
    @Binding var userProperties: [MQTTUserProperty]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MQTT 5 Properties")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glass)
            }
            .padding()

            Divider()

            Form {
                Section("Publish Properties") {
                    TextField("Content Type", text: $mqttContentType, prompt: Text("e.g. application/json"))
                        .autocorrectionDisabled()
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    TextField("Response Topic", text: $responseTopic, prompt: Text("e.g. reply/topic"))
                        .autocorrectionDisabled()
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    TextField("Correlation Data", text: $correlationData, prompt: Text("Hex, e.g. DE AD BE EF"))
                        .autocorrectionDisabled()
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    TextField("Message Expiry Interval", text: $messageExpiryInterval, prompt: Text("Seconds"))
                        #if !os(macOS)
                        .keyboardType(.numberPad)
                        #endif

                    Picker("Payload Format Indicator", selection: $payloadFormatIndicator) {
                        ForEach(PayloadFormatIndicatorOption.allCases, id: \.self) { option in
                            Text(option.localizedName).tag(option)
                        }
                    }
                }

                Section {
                    ForEach(Array(userProperties.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 4) {
                            TextField("Key", text: $userProperties[index].key)
                                .autocorrectionDisabled()
                                #if !os(macOS)
                                .textInputAutocapitalization(.never)
                                #endif
                            TextField("Value", text: $userProperties[index].value)
                                .autocorrectionDisabled()
                                #if !os(macOS)
                                .textInputAutocapitalization(.never)
                                #endif
                            Button {
                                userProperties.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button {
                        userProperties.append(MQTTUserProperty(key: "", value: ""))
                    } label: {
                        Label("Add User Property", systemImage: "plus")
                    }
                } header: {
                    Text("User Properties")
                }
            }
            .formStyle(.grouped)
        }
        #if os(macOS)
        .frame(width: 480, height: 500)
        #endif
    }
}

final class XMLValidationDelegate: NSObject, XMLParserDelegate {}

final class XMLPrettifyDelegate: NSObject, XMLParserDelegate {
    var result = ""
    private var depth = 0
    private var currentCharacters = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        flushCharacters()
        let indent = String(repeating: "    ", count: depth)
        var line = "\(indent)<\(elementName)"
        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            line += " \(key)=\"\(value)\""
        }
        line += ">"
        result += line + "\n"
        depth += 1
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName: String?) {
        let chars = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
        if !chars.isEmpty {
            // Inline text: remove last newline, append text + closing tag
            if result.hasSuffix("\n") {
                result.removeLast()
            }
            result += chars
            depth -= 1
            result += "</\(elementName)>\n"
        } else {
            currentCharacters = ""
            depth -= 1
            let indent = String(repeating: "    ", count: depth)
            result += "\(indent)</\(elementName)>\n"
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentCharacters += string
    }

    private func flushCharacters() {
        currentCharacters = ""
    }
}
