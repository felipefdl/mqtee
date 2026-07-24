import SwiftUI

enum PublishFeedback {
    case success
    case failure(String)
}

struct PublishPanelContent: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    @Bindable var session: SessionStore
    var isPinned: Bool = false
    var onTogglePin: (() -> Void)? = nil
    @State var topic: String = ""
    @State var payload: String = ""
    @State var qos: QoSLevel = .atMostOnce
    @State var retain: Bool = false
    @State var payloadFormat: PublishPayloadFormat = .text
    @State var jsonIsValid: Bool = true
    @State var jsonError: String?
    @State var hexIsValid: Bool = true
    @State var hexError: String?
    @State var base64IsValid: Bool = true
    @State var base64Error: String?
    @State var xmlIsValid: Bool = true
    @State var xmlError: String?
    @State var validationTask: Task<Void, Never>?
    @State var autoSaveTask: Task<Void, Never>?
    @State var isLoadingTab: Bool = false
    @State var renameTabId: UUID?
    @State var renameText: String = ""
    @State var publishFeedback: PublishFeedback?
    @State var feedbackTask: Task<Void, Never>?
    @State var showCloseAllConfirmation: Bool = false
    @State private var showMqtt5Sheet: Bool = false
    @State var mqttContentType: String = ""
    @State var responseTopic: String = ""
    @State var correlationData: String = ""
    @State var messageExpiryInterval: String = ""
    @State var payloadFormatIndicator: PayloadFormatIndicatorOption = .unspecified
    @State var userProperties: [MQTTUserProperty] = []

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if horizontalSizeClass == .compact {
                VStack(spacing: 0) {
                    if session.publishTabs.count > 1 {
                        tabPickerBar
                        Divider()
                    }
                    contentArea
                }
            } else {
                HStack(spacing: 0) {
                    if session.publishTabs.count > 1 {
                        tabSidebar
                        Divider()
                    }
                    contentArea
                }
            }
        }
        .onAppear { loadActiveTab() }
        .onDisappear {
            autoSaveTask?.cancel()
            feedbackTask?.cancel()
            saveToActiveTab()
        }
        .onChange(of: session.activePublishTabId) {
            renameTabId = nil
            loadActiveTab()
        }
        .onChange(of: payload) { _, _ in
            guard !isLoadingTab else { return }
            scheduleValidation()
            scheduleAutoSave()
        }
        .onChange(of: topic) { _, _ in
            guard !isLoadingTab else { return }
            scheduleAutoSave()
        }
        .onChange(of: qos) { _, _ in
            guard !isLoadingTab else { return }
            scheduleAutoSave()
        }
        .onChange(of: retain) { _, _ in
            guard !isLoadingTab else { return }
            scheduleAutoSave()
        }
        .onChange(of: mqttContentType) { _, _ in
            guard !isLoadingTab else { return }
            scheduleAutoSave()
        }
        .onChange(of: responseTopic) { _, _ in
            guard !isLoadingTab else { return }
            scheduleAutoSave()
        }
        .onChange(of: correlationData) { _, _ in
            guard !isLoadingTab else { return }
            scheduleAutoSave()
        }
        .onChange(of: messageExpiryInterval) { _, _ in
            guard !isLoadingTab else { return }
            scheduleAutoSave()
        }
        .onChange(of: payloadFormatIndicator) { _, _ in
            guard !isLoadingTab else { return }
            scheduleAutoSave()
        }
        .onChange(of: userProperties) { _, _ in
            guard !isLoadingTab else { return }
            scheduleAutoSave()
        }
        .onChange(of: session.triggerPublish) { _, shouldPublish in
            guard shouldPublish else { return }
            session.triggerPublish = false
            performPublish()
        }
        .onChange(of: session.triggerPrettify) { _, shouldPrettify in
            guard shouldPrettify else { return }
            session.triggerPrettify = false
            switch payloadFormat {
            case .json: prettifyJSON()
            case .xml: prettifyXML()
            default: break
            }
        }
        .onChange(of: payloadFormat) { _, newFormat in
            guard !isLoadingTab else { return }
            validationTask?.cancel()
            clearAllValidation()
            switch newFormat {
            case .json: validateJSON()
            case .hex: validateHex()
            case .base64: validateBase64()
            case .xml: validateXML()
            case .text: break
            }
            scheduleAutoSave()
        }
        .confirmationDialog("Delete all tabs?", isPresented: $showCloseAllConfirmation) {
            Button("Delete All", role: .destructive) {
                session.closeAllPublishTabs()
                loadActiveTab()
            }
        } message: {
            Text("This will delete all publish tabs and create a new empty one.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                session.addPublishTab()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .tint(.primary)
            .help("New tab")

            Menu {
                Button("Delete Tab") {
                    if let activeId = session.activePublishTabId {
                        session.removePublishTab(activeId)
                    }
                }
                Button("Delete All", role: .destructive) {
                    showCloseAllConfirmation = true
                }
            } label: {
                Image(systemName: "trash")
            } primaryAction: {
                if let activeId = session.activePublishTabId {
                    session.removePublishTab(activeId)
                }
            }
            .menuIndicator(.hidden)
            .buttonStyle(.borderless)
            .tint(.primary)
            .help("Delete current tab")
            .disabled(session.publishTabs.count <= 1)

            if let onTogglePin {
                Button {
                    onTogglePin()
                } label: {
                    Image(systemName: isPinned ? "arrow.up.forward.square" : "rectangle.bottomhalf.inset.filled")
                }
                .buttonStyle(.borderless)
                .tint(.primary)
                .help(isPinned ? "Float as popover" : "Dock as panel")
            }

            Spacer()

            Button {
                performPublish()
            } label: {
                publishButtonLabel
            }
            .buttonStyle(.glassProminent)
            .tint(publishButtonTint)
            .controlSize(.small)
            .disabled(topic.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Topic") {
                TextField("e.g. sensors/temperature", text: $topic)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }

            LabeledContent("Format") {
                Picker("Format", selection: $payloadFormat) {
                    ForEach(PublishPayloadFormat.allCases, id: \.self) { format in
                        Text(format.localizedName).tag(format)
                    }
                }
                #if os(macOS)
                .pickerStyle(.segmented)
                #else
                .pickerStyle(.menu)
                #endif
                .labelsHidden()
            }

            payloadEditor

            HStack {
                Picker("QoS", selection: $qos) {
                    ForEach(QoSLevel.allCases, id: \.self) { level in
                        Text("\(level.rawValue) - \(level.description)").tag(level)
                    }
                }
                .fixedSize()
                .tint(.primary)

                Spacer()

                Toggle("Retain", isOn: $retain)
                    .fixedSize()
            }

            if session.connection.mqttVersion == .v5 {
                Button {
                    showMqtt5Sheet = true
                } label: {
                    HStack {
                        Label("MQTT 5 Properties", systemImage: "list.bullet.rectangle")
                        Spacer()
                        if hasMqtt5PropertiesSet {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .sheet(isPresented: $showMqtt5Sheet) {
                    Mqtt5PropertiesSheet(
                        mqttContentType: $mqttContentType,
                        responseTopic: $responseTopic,
                        correlationData: $correlationData,
                        messageExpiryInterval: $messageExpiryInterval,
                        payloadFormatIndicator: $payloadFormatIndicator,
                        userProperties: $userProperties
                    )
                }
            }
        }
        .padding(12)
    }

    private var hasMqtt5PropertiesSet: Bool {
        !mqttContentType.isEmpty || !responseTopic.isEmpty || !correlationData.isEmpty
            || !messageExpiryInterval.isEmpty || payloadFormatIndicator != .unspecified
            || !userProperties.isEmpty
    }
}

#Preview("Publish Panel") {
    PublishPanelContent(session: SessionStore.preview())
}
