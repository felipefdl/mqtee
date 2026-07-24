//
//  ConnectionEditorView.swift
//  mqtee
//

import os
import SwiftUI
import UniformTypeIdentifiers

struct ConnectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var store: ConnectionStore
    var existingConnection: Connection?

    // General
    @State var name: String = ""
    @State var host: String = ""
    @State var port: String = "1883"
    @State var selectedFolderId: UUID?

    // MQTT Settings
    @State var mqttVersion: MQTTVersion = .v311
    @State var clientId: String = ""
    @State var cleanSession: Bool = true
    @State var keepAlive: String = "60"
    @State var sessionExpiry: String = ""

    // Authentication
    @State var username: String = ""
    @State var password: String = ""

    // Security
    @State var useTLS: Bool = false
    @State var useClientCertificate: Bool = false
    @State var allowInsecureTLS: Bool = false
    @State var clientCertificateData: Data?
    @State var clientKeyData: Data?
    @State var caCertificateData: Data?

    // Last Will
    @State var lastWillEnabled: Bool = false
    @State var lastWillTopic: String = ""
    @State var lastWillMessage: String = ""
    @State var lastWillQoS: QoSLevel = .atMostOnce
    @State var lastWillRetain: Bool = false

    // Session Persistence
    @State var persistSession: Bool = true

    // Auto-Subscribe
    @State var autoSubscribe: Bool = false

    // Test Connection
    @State var testStatus: ConnectionTestStatus = .idle
    @State var testErrorMessage: String?

    #if os(macOS)
    @State private var selectedTab: EditorTab = .general
    #endif

    let keychain = KeychainService.shared

    init(store: ConnectionStore, existingConnection: Connection? = nil) {
        self.store = store
        self.existingConnection = existingConnection

        if let connection = existingConnection {
            _name = State(initialValue: connection.name)
            _host = State(initialValue: connection.host)
            _port = State(initialValue: String(connection.port))
            _selectedFolderId = State(initialValue: connection.folderId)
            _mqttVersion = State(initialValue: connection.mqttVersion)
            _clientId = State(initialValue: MQTTService.deviceClientId(for: connection.id))
            _cleanSession = State(initialValue: connection.cleanSession)
            _keepAlive = State(initialValue: String(connection.keepAlive))
            _sessionExpiry = State(initialValue: connection.sessionExpiry.map { String($0) } ?? "")
            _username = State(initialValue: connection.username ?? "")
            _useTLS = State(initialValue: connection.useTLS)
            _useClientCertificate = State(initialValue: connection.useClientCertificate)
            _allowInsecureTLS = State(initialValue: connection.allowInsecureTLS)
            _lastWillEnabled = State(initialValue: connection.lastWill.enabled)
            _lastWillTopic = State(initialValue: connection.lastWill.topic)
            _lastWillMessage = State(initialValue: connection.lastWill.message)
            _lastWillQoS = State(initialValue: connection.lastWill.qos)
            _lastWillRetain = State(initialValue: connection.lastWill.retain)
            _persistSession = State(initialValue: connection.persistSession)
            _autoSubscribe = State(initialValue: connection.autoSubscribe)

            // Load credentials from Keychain
            if let credentials = try? KeychainService.shared.loadCredentials(for: connection.id) {
                _username = State(initialValue: credentials.username ?? "")
                _password = State(initialValue: credentials.password ?? "")
                _clientCertificateData = State(initialValue: credentials.clientCertificate)
                _clientKeyData = State(initialValue: credentials.clientKey)
                _caCertificateData = State(initialValue: credentials.caCertificate)
            }
        }
    }

    var body: some View {
        sheetContent
            #if !os(macOS)
            .presentationSizing(.form)
            .interactiveDismissDisabled()
            #endif
            .alert("Connection Failed", isPresented: .init(
                get: { testErrorMessage != nil },
                set: { if !$0 { testErrorMessage = nil } }
            )) {
                Button("OK") { testErrorMessage = nil }
            } message: {
                if let message = testErrorMessage {
                    Text(message)
                }
            }
    }

    @ViewBuilder
    private var sheetContent: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                List(selection: Binding(
                    get: { selectedTab as EditorTab? },
                    set: { if let tab = $0 { selectedTab = tab } }
                )) {
                    ForEach(EditorTab.allCases, id: \.self) { tab in
                        Label(tab.label, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 160)

                editorContent
            }

            Divider()

            HStack {
                testConnectionButton
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    saveConnection()
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || host.isEmpty)
            }
            .padding(12)
        }
        .frame(width: 650, height: 500)
        #else
        NavigationStack {
            TabView {
                Tab("General", systemImage: "server.rack") {
                    generalForm
                }
                Tab("Auth", systemImage: "person.badge.key") {
                    authenticationForm
                }
                Tab("Security", systemImage: "lock.shield") {
                    securityForm
                }
                Tab("Last Will", systemImage: "exclamationmark.bubble") {
                    lastWillForm
                }
                Tab("Advanced", systemImage: "gearshape.2") {
                    advancedForm
                }
            }
            .navigationTitle(existingConnection == nil ? "New Connection" : "Edit Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConnection()
                        dismiss()
                    }
                    .disabled(name.isEmpty || host.isEmpty)
                }
            }
        }
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private var editorContent: some View {
        switch selectedTab {
        case .general: generalForm
        case .auth: authenticationForm
        case .security: securityForm
        case .lastWill: lastWillForm
        case .advanced: advancedForm
        }
    }
    #endif
}

#Preview {
    ConnectionEditorView(store: ConnectionStore())
}
