//
//  ConnectionEditorView+Sections.swift
//  mqtee
//

import SwiftUI

extension ConnectionEditorView {
    var authenticationForm: some View {
        Form {
            authenticationSection
        }
        .formStyle(.grouped)
        #if !os(macOS)
        .keyboardDismissable()
        #endif
    }

    var securityForm: some View {
        Form {
            securitySection
        }
        .formStyle(.grouped)
    }

    var lastWillForm: some View {
        Form {
            lastWillSection
        }
        .formStyle(.grouped)
        #if !os(macOS)
        .keyboardDismissable()
        #endif
    }

    var advancedForm: some View {
        Form {
            sessionSection
            storageSection
        }
        .formStyle(.grouped)
        #if !os(macOS)
        .keyboardDismissable()
        #endif
    }

    var authenticationSection: some View {
        Section {
            TextField("Username", text: $username)
                .textContentType(.username)
                .autocorrectionDisabled()
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                #endif

            SecureField("Password", text: $password)
                .textContentType(.password)
                .autocorrectionDisabled()
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                #endif
        } header: {
            Text("Authentication")
        } footer: {
            Text("Credentials are stored securely in your Keychain.")
        }
    }

    var securitySection: some View {
        Section("Security") {
            Toggle("Enable TLS", isOn: $useTLS)
                .onChange(of: useTLS) { _, _ in
                    updatePortForTLS()
                }

            if useTLS {
                Toggle("Allow insecure certificates", isOn: $allowInsecureTLS)

                CertificateFilePicker(
                    label: "CA Certificate",
                    data: $caCertificateData,
                    hint: "Optional - for self-signed servers"
                )

                Toggle("Use Client Certificate", isOn: $useClientCertificate)

                if useClientCertificate {
                    CertificateFilePicker(
                        label: "Client Certificate",
                        data: $clientCertificateData,
                        hint: "PEM or DER format"
                    )
                    CertificateFilePicker(
                        label: "Client Private Key",
                        data: $clientKeyData,
                        hint: "PEM format"
                    )
                }
            }
        }
    }

    var lastWillSection: some View {
        Section {
            Toggle("Enable Last Will", isOn: $lastWillEnabled)

            if lastWillEnabled {
                TextField("Topic", text: $lastWillTopic, prompt: Text("status/offline"))

                TextEditor(text: $lastWillMessage)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 60)

                Picker("QoS", selection: $lastWillQoS) {
                    ForEach(QoSLevel.allCases, id: \.self) { qos in
                        Text(qos.shortName).tag(qos)
                    }
                }

                Toggle("Retain", isOn: $lastWillRetain)
            }
        } header: {
            Text("Last Will and Testament")
        } footer: {
            Text("The Last Will message is sent by the broker when the client disconnects unexpectedly.")
        }
    }

    var sessionSection: some View {
        Section {
            Toggle("Clean Session", isOn: $cleanSession)

            LabeledContent("Keep Alive") {
                HStack {
                    TextField("60", text: $keepAlive)
                        .frame(width: 60)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
            }

            if mqttVersion == .v5 {
                LabeledContent("Session Expiry") {
                    HStack {
                        TextField("0", text: $sessionExpiry)
                            .frame(width: 60)
                        Text("seconds")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Session")
        } footer: {
            if mqttVersion == .v311 {
                Text("Clean Session removes all subscriptions and queued messages on connect.")
            } else {
                Text("Clean Start begins a new session. Session Expiry controls how long the broker keeps the session after disconnect.")
            }
        }
    }

    var storageSection: some View {
        Section {
            Toggle("Persist Session Locally", isOn: $persistSession)
        } header: {
            Text("Local Storage")
        } footer: {
            Text("Save subscriptions and message history. Auto-resubscribe when reconnecting.")
        }
    }
}
