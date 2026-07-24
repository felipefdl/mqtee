//
//  SettingsViews.swift
//  mqtee
//
//  Created by Felipe Lima on 2/22/26.
//

import SwiftUI

#if !os(macOS)
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onResetAllData: (() -> Void)?
    #if DEBUG
    var onLoadSampleData: (() -> Void)?
    #endif

    var body: some View {
        NavigationStack {
            generalSettings
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    private var generalSettings: some View {
        #if DEBUG
        GeneralSettingsView(
            onResetAllData: { dismiss(); onResetAllData?() },
            onLoadSampleData: { dismiss(); onLoadSampleData?() }
        )
        #else
        GeneralSettingsView(onResetAllData: { dismiss(); onResetAllData?() })
        #endif
    }
}
#endif

struct GeneralSettingsView: View {
    @AppStorage("defaultMQTTVersion") private var defaultMQTTVersion = "3.1.1"
    @AppStorage("defaultKeepAlive") private var defaultKeepAlive = 60
    @AppStorage("autoReconnect") private var autoReconnect = true
    @AppStorage("reconnectInterval") private var reconnectInterval = 5
    @AppStorage("maxMessagesInMemory") private var maxMessagesInMemory = 10000
    @AppStorage("maxPersistedMessages") private var maxPersistedMessages = 1000
    @AppStorage("batchLogThreshold") private var batchLogThreshold = 20
    @AppStorage("compactPayloadLines") private var compactLines = 2
    @AppStorage("comfortablePayloadLines") private var comfortableLines = 8

    #if !os(macOS)
    var onResetAllData: (() -> Void)?
    #if DEBUG
    var onLoadSampleData: (() -> Void)?
    #endif
    @State private var showingResetSheet = false
    #endif

    var body: some View {
        Form {
            Section("Protocol") {
                Picker("Default MQTT Version", selection: $defaultMQTTVersion) {
                    Text("MQTT 3.1.1").tag("3.1.1")
                    Text("MQTT 5.0").tag("5.0")
                }

                Stepper("Keep alive: \(defaultKeepAlive)s", value: $defaultKeepAlive, in: 5...300, step: 5)
            }

            Section("Connection") {
                Toggle("Auto-reconnect on disconnect", isOn: $autoReconnect)

                if autoReconnect {
                    Stepper(
                        "Reconnect interval: \(reconnectInterval)s",
                        value: $reconnectInterval, in: 1...60
                    )
                }
            }

            Section("Display") {
                Stepper("Compact payload lines: \(compactLines)", value: $compactLines, in: 1...4)
                Stepper("Comfortable payload lines: \(comfortableLines)", value: $comfortableLines, in: 4...20)
            }

            Section("Message History") {
                Stepper(
                    "Max in memory: \(maxMessagesInMemory)",
                    value: $maxMessagesInMemory, in: 1000...100_000, step: 1000
                )
                Text("Maximum number of messages kept in memory per connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper(
                    "Max persisted: \(maxPersistedMessages)",
                    value: $maxPersistedMessages, in: 100...10_000, step: 100
                )
                Text("Maximum number of messages saved to disk per connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper(
                    "Batch log threshold: \(batchLogThreshold)",
                    value: $batchLogThreshold, in: 5...100, step: 5
                )
                Text("Messages per flush below this are logged individually; above are summarized.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Legal") {
                Link("Privacy Policy", destination: URL(string: "https://mqtee.app/privacy/")!)
                Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            #if !os(macOS)
            Section {
                NavigationLink {
                    LicensesSettingsView()
                } label: {
                    Label("Open Source Licenses", systemImage: "doc.text")
                }
            }

            Section {
                Button("Reset All Data...", role: .destructive) {
                    showingResetSheet = true
                }
            }

            #if DEBUG
            Section("Debug") {
                Button("Load Sample Brokers") {
                    onLoadSampleData?()
                }
            }
            #endif
            #endif
        }
        .formStyle(.grouped)
        #if !os(macOS)
        .sheet(isPresented: $showingResetSheet) {
            ResetDataSheet {
                onResetAllData?()
            }
        }
        #endif
    }
}
