import SwiftUI

enum PayloadDisplayMode: String, CaseIterable {
    case formatted = "Formatted"
    case raw = "Raw"
    case hex = "Hex"
    case base64 = "Base64"

    var localizedName: String {
        rawValue
    }
}

struct PayloadTaskID: Equatable {
    let messageId: UUID?
    let mode: PayloadDisplayMode
    let colorScheme: ColorScheme
}

struct PayloadDisplayView: View {
    var message: MQTTMessage?
    @State private var displayMode: PayloadDisplayMode = .formatted
    @State private var renderedContent: AttributedString?
    @State private var contentType: PayloadContentType?
    @Environment(\.colorScheme) private var colorScheme

    private static let formattedSizeLimit = 64_000

    private var hasMessage: Bool {
        message != nil
    }

    private var isFormattedAvailable: Bool {
        (message?.payload.count ?? 0) <= Self.formattedSizeLimit
    }

    private func formattedSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1_048_576 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
        }
    }

    private var payloadModePicker: some View {
        Picker("Display", selection: $displayMode) {
            ForEach(PayloadDisplayMode.allCases, id: \.self) { mode in
                Text(mode.localizedName)
                    .tag(mode)
            }
        }
        #if os(macOS)
        .pickerStyle(.menu)
        #else
        .pickerStyle(.segmented)
        #endif
        .labelsHidden()
        .disabled(!hasMessage)
        .onChange(of: message?.id) {
            if !isFormattedAvailable && displayMode == .formatted {
                displayMode = .raw
            }
        }
        .onChange(of: displayMode) {
            if !isFormattedAvailable && displayMode == .formatted {
                displayMode = .raw
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                #if os(macOS)
                Text("Payload")
                    .font(.headline)
                    .foregroundStyle(hasMessage ? .primary : .tertiary)
                #endif

                #if os(macOS)
                if let contentType {
                    Label(contentType.localizedName, systemImage: contentType.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.fill.tertiary, in: Capsule())
                        .layoutPriority(-1)
                }
                #endif

                Spacer(minLength: 4)

                payloadModePicker
            }
            #if os(macOS)
            .padding()
            .frame(height: 66)
            #else
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(height: 54)
            #endif

            if !isFormattedAvailable && hasMessage {
                Text("Formatted view unavailable for large payloads")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }

            Divider()

            if let message {
                HStack(spacing: 0) {
                    Text(message.topic)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 8)

                    // Metadata order matches MessageRowView sent order: paperplane · QoS · Retained · size · time
                    // (MessageRowView inverts order for received messages)
                    HStack(spacing: 0) {
                        if message.sentByMe {
                            Image(systemName: "paperplane.fill")
                                .font(.caption2)
                            Text(" \u{00B7} ")
                        }
                        Text(message.qos.shortName)
                        if message.retained {
                            Text(" \u{00B7} Retained")
                        }
                        Text(" \u{00B7} \(formattedSize(message.payload.count))")
                        Text(" \u{00B7} \(message.timestamp.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)))")
                    }
                    .layoutPriority(1)
                }
                .font(.caption2)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.horizontal)
                .padding(.top, 8)
            }

            if let message, message.hasMQTT5Properties {
                mqtt5PropertiesSection(for: message)
                Divider()
            }

            ScrollView {
                if message != nil {
                    if let renderedContent {
                        Text(renderedContent)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding([.horizontal, .bottom])
                            .padding(.top, 4)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    }
                } else {
                    Text("No message selected")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
            }
        }
        .task(id: PayloadTaskID(messageId: message?.id, mode: displayMode, colorScheme: colorScheme)) {
            guard let message else {
                renderedContent = nil
                contentType = nil
                return
            }
            let scheme = colorScheme
            let mode = displayMode
            let payload = message.payload
            let payloadSize = payload.count
            let sizeLimit = Self.formattedSizeLimit
            let (content, detected) = await Task.detached {
                let detected = PayloadContentType.detect(from: payload)
                let monoFont = Font.system(.body, design: .monospaced)

                switch mode {
                case .formatted where payloadSize <= sizeLimit:
                    let formatted = message.formattedPayload
                    if detected == .json {
                        let theme = SyntaxTheme(colorScheme: scheme)
                        return (JSONHighlighter.highlight(formatted, theme: theme), detected)
                    }
                    var plain = AttributedString(formatted)
                    plain.font = monoFont
                    return (plain, detected)

                case .formatted, .raw:
                    let text = message.payloadString
                    var plain = AttributedString(text)
                    plain.font = monoFont
                    return (plain, detected)

                case .hex:
                    let hex = payload.map { String(format: "%02X", $0) }.joined(separator: " ")
                    var plain = AttributedString(hex)
                    plain.font = monoFont
                    return (plain, detected)

                case .base64:
                    let b64 = payload.base64EncodedString(options: [.lineLength76Characters, .endLineWithLineFeed])
                    var plain = AttributedString(b64)
                    plain.font = monoFont
                    return (plain, detected)
                }
            }.value
            renderedContent = content
            contentType = detected
        }
    }

    // MARK: - MQTT 5 Properties Section

    @ViewBuilder
    private func mqtt5PropertiesSection(for message: MQTTMessage) -> some View {
        DisclosureGroup("MQTT 5 Properties") {
            VStack(alignment: .leading, spacing: 4) {
                if let ct = message.mqttContentType {
                    propertyRow("Content Type", value: ct)
                }
                if let rt = message.responseTopic {
                    propertyRow("Response Topic", value: rt)
                }
                if let data = message.correlationData {
                    let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                    propertyRow("Correlation Data", value: hex)
                }
                if let indicator = message.payloadFormatIndicator {
                    propertyRow("Payload Format", value: indicator == 1 ? "UTF-8 (1)" : "Bytes (0)")
                }
                if let expiry = message.messageExpiryInterval {
                    propertyRow("Message Expiry", value: "\(expiry)s")
                }
                if !message.userProperties.isEmpty {
                    Text("User Properties")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(message.userProperties.enumerated()), id: \.offset) { _, prop in
                        propertyRow(prop.key, value: prop.value)
                    }
                }
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func propertyRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(minWidth: 100, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .fontDesign(.monospaced)
        }
    }
}

#Preview("Payload Highlighting") {
    let jsonMessage = MQTTMessage(
        topic: "sensors/temperature",
        payloadString: "{\"value\": 22.5, \"unit\": \"C\", \"active\": true, \"error\": null}",
        qos: .atLeastOnce,
        retained: false
    )
    PayloadDisplayView(message: jsonMessage)
        .frame(width: 500, height: 400)
}

#Preview("Payload Highlighting Light") {
    let jsonMessage = MQTTMessage(
        topic: "sensors/temperature",
        payloadString: "{\"value\": 22.5, \"unit\": \"C\", \"active\": true, \"error\": null}",
        qos: .atLeastOnce,
        retained: false
    )
    PayloadDisplayView(message: jsonMessage)
        .frame(width: 500, height: 400)
        .preferredColorScheme(.light)
}
