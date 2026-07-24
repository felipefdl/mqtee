import SwiftUI

extension PublishPanelContent {
    var tabSidebar: some View {
        List(selection: tabSelection) {
            ForEach(session.publishTabs) { tab in
                if renameTabId == tab.id {
                    TextField("Name", text: $renameText)
                        .textFieldStyle(.plain)
                        .onSubmit { commitRename() }
                        #if os(macOS)
                        .onExitCommand { renameTabId = nil }
                        #endif
                        .tag(tab.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                } else {
                    Text(tab.displayName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .tag(tab.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .contextMenu {
                            Button("Rename") {
                                renameText = tab.name ?? ""
                                renameTabId = tab.id
                            }
                            Button("Delete") {
                                session.removePublishTab(tab.id)
                            }
                            .disabled(session.publishTabs.count <= 1)
                            Divider()
                            Button("Delete All", role: .destructive) {
                                showCloseAllConfirmation = true
                            }
                            .disabled(session.publishTabs.count <= 1)
                        }
                }
            }
        }
        #if os(macOS)
        .listStyle(.plain)
        #else
        .listStyle(.plain)
        #endif
        .environment(\.defaultMinListRowHeight, 20)
        .frame(width: 110)
    }

    var tabPickerBar: some View {
        HStack {
            if renameTabId != nil {
                TextField("Name", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitRename() }
            } else {
                Picker(selection: tabSelection) {
                    ForEach(session.publishTabs) { tab in
                        Text(tab.displayName).tag(Optional(tab.id))
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .contextMenu {
                    Button("Rename") {
                        if let activeId = session.activePublishTabId,
                           let tab = session.publishTabs.first(where: { $0.id == activeId }) {
                            renameText = tab.name ?? ""
                            renameTabId = tab.id
                        }
                    }
                    Button("Delete", role: .destructive) {
                        if let activeId = session.activePublishTabId {
                            session.removePublishTab(activeId)
                        }
                    }
                    .disabled(session.publishTabs.count <= 1)
                    Divider()
                    Button("Close All", role: .destructive) {
                        showCloseAllConfirmation = true
                    }
                    .disabled(session.publishTabs.count <= 1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    var tabSelection: Binding<UUID?> {
        Binding(
            get: { session.activePublishTabId ?? session.publishTabs.first?.id },
            set: { newId in
                guard let newId else { return }
                saveToActiveTab()
                session.selectPublishTab(newId)
            }
        )
    }

    func loadActiveTab() {
        guard let tab = session.activePublishTab else { return }
        isLoadingTab = true
        topic = tab.topic
        payload = tab.payload
        payloadFormat = tab.payloadFormat
        qos = tab.qos
        retain = tab.retain
        mqttContentType = tab.mqttContentType
        responseTopic = tab.responseTopic
        correlationData = tab.correlationData
        messageExpiryInterval = tab.messageExpiryInterval
        payloadFormatIndicator = tab.payloadFormatIndicator
        userProperties = tab.userProperties
        isLoadingTab = false
        switch payloadFormat {
        case .json: validateJSON()
        case .hex: validateHex()
        case .base64: validateBase64()
        case .xml: validateXML()
        case .text: break
        }
    }

    func saveToActiveTab() {
        guard var tab = session.activePublishTab else { return }
        tab.topic = topic
        tab.payload = payload
        tab.payloadFormat = payloadFormat
        tab.qos = qos
        tab.retain = retain
        tab.mqttContentType = mqttContentType
        tab.responseTopic = responseTopic
        tab.correlationData = correlationData
        tab.messageExpiryInterval = messageExpiryInterval
        tab.payloadFormatIndicator = payloadFormatIndicator
        tab.userProperties = userProperties
        session.updatePublishTab(tab)
    }

    func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            saveToActiveTab()
        }
    }

    func commitRename() {
        guard let tabId = renameTabId,
              var tab = session.publishTabs.first(where: { $0.id == tabId }) else { return }
        tab.name = renameText.isEmpty ? nil : renameText
        session.updatePublishTab(tab)
        renameTabId = nil
    }
}
