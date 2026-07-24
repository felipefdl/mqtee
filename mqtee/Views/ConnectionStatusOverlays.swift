//
//  ConnectionStatusOverlays.swift
//  mqtee
//

import SwiftUI

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return String(localized: "Version \(version) (\(build))", comment: "App version display")
    }
}

// MARK: - Connecting Sheet

struct ConnectingSheet: View {
    let connectionName: String
    let connectionId: UUID
    var onCancel: () -> Void

    private var latestEntry: LogEntry? {
        LogStore.shared.latestEntry(for: connectionId)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text(connectionName)
                .font(.headline)
            Text(latestEntry?.message ?? "Starting...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.glass)
        }
        .padding()
        #if os(macOS)
        .frame(width: 300, height: 200)
        #endif
    }
}

#if os(macOS)
struct DisconnectPopover: View {
    let connectionName: String
    var onDisconnect: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Disconnect from \(connectionName)?")
                .font(.headline)

            HStack(spacing: 8) {
                Button("Cancel") { dismiss() }
                Button("Disconnect", role: .destructive) {
                    onDisconnect()
                }
            }
        }
        .padding()
    }
}
#endif
