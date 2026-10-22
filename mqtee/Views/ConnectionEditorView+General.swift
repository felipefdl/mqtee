//
//  ConnectionEditorView+General.swift
//  mqtee
//

import SwiftUI

extension ConnectionEditorView {
    var generalForm: some View {
        Form {
            connectionSection
            clientSection
            subscriptionSection
            folderSection
            #if !os(macOS)
            testConnectionSection
            #endif
        }
        .formStyle(.grouped)
        #if !os(macOS)
        .keyboardDismissable()
        #endif
    }

    var connectionSection: some View {
        Section("Connection") {
            Picker("MQTT Version", selection: $mqttVersion) {
                ForEach(MQTTVersion.allCases, id: \.self) { version in
                    Text(version.displayName).tag(version)
                }
            }
            .onChange(of: mqttVersion) { _, _ in
                updatePortForTLS()
            }

            #if os(macOS)
            TextField("Name", text: $name, prompt: Text("My Connection"))

            HStack {
                TextField("Host", text: $host, prompt: Text("broker.example.com"))
                    .textContentType(.none)
                    .autocorrectionDisabled()

                TextField("Port", text: $port, prompt: Text("1883"))
                    .frame(width: 70)
            }
            #else
            LabeledContent("Name") {
                TextField("Name", text: $name, prompt: Text("My Connection"))
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
            }

            LabeledContent("Host") {
                TextField("Host", text: $host, prompt: Text("broker.example.com"))
                    .multilineTextAlignment(.trailing)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            LabeledContent("Port") {
                TextField("Port", text: $port, prompt: Text("1883"))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
            #endif
        }
    }

    var clientSection: some View {
        Section {
            #if os(macOS)
            HStack {
                TextField("Client ID", text: $clientId, prompt: Text("Auto-generated if empty"))
                    .textContentType(.none)
                    .autocorrectionDisabled()

                Button("Generate") {
                    clientId = "mqtee-\(UUID().uuidString.prefix(8))"
                }
            }
            #else
            LabeledContent("Client ID") {
                TextField("Client ID", text: $clientId, prompt: Text("Auto-generated"))
                    .multilineTextAlignment(.trailing)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Button("Generate") {
                clientId = "mqtee-\(UUID().uuidString.prefix(8))"
            }
            #endif
        } header: {
            Text("Client")
        } footer: {
            clientIdCaption
        }
    }

    var subscriptionSection: some View {
        Section {
            Toggle("Auto-subscribe (# + $SYS/#)", isOn: $autoSubscribe)
        } header: {
            Text("Subscription")
        } footer: {
            Text("Subscribes to all topics on connect. Not recommended on public brokers — high message volume may drain device resources.")
        }
        .onChange(of: host) { _, newHost in
            let trimmed = newHost.trimmingCharacters(in: .whitespaces).lowercased()
            let isLocal = trimmed.hasPrefix("192.") ||
                          trimmed.hasPrefix("10.") ||
                          trimmed.hasPrefix("172.") ||
                          trimmed == "localhost" ||
                          trimmed == "127.0.0.1" ||
                          trimmed == "::1"
            if isLocal {
                autoSubscribe = true
            } else {
                autoSubscribe = false
            }
        }
    }

    var folderSection: some View {
        Section("Folder") {
            Picker("Folder", selection: $selectedFolderId) {
                Text("None").tag(nil as UUID?)
                ForEach(store.sortedFolders) { folder in
                    HStack {
                        Circle()
                            .fill(folder.color.color)
                            .frame(width: 8, height: 8)
                        Text(folder.name)
                    }
                    .tag(folder.id as UUID?)
                }
            }
        }
    }

    @ViewBuilder
    var clientIdCaption: some View {
        let conflicts = existingConnection.map {
            store.deviceClientIdConflicts(for: $0.id, clientId: clientId)
        } ?? []

        if !conflicts.isEmpty {
            Label {
                let names = conflicts.joined(separator: ", ")
                Text("Same client ID is used on: \(names). This may cause connection conflicts.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .foregroundStyle(.yellow)
        } else {
            Text("Each device uses its own client ID to prevent connection conflicts when synced via iCloud.")
        }
    }
}
