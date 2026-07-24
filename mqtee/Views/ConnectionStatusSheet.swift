import SwiftUI

#if !os(macOS)
struct ConnectionStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: SessionStore
    var folder: ConnectionFolder?
    @State private var showClearConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            List {
                headerSection
                statusSection
                statisticsSection
                actionsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Connection Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let folder {
                        Text(folder.name)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(folder.color.color)
                            )
                    }
                    Text(session.connection.name)
                        .font(.headline)
                }

                Text(session.connection.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(session.connection.mqttVersion.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

                    if session.connection.useTLS {
                        Label("TLS", systemImage: "lock.fill")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section("Status") {
            HStack(spacing: 6) {
                Circle()
                    .fill(session.statusDotColor)
                    .frame(width: 8, height: 8)
                Text(session.statusLabel)
            }

            if let since = session.connectedSince {
                LabeledContent("Connected at") {
                    Text(since, style: .time)
                }

                LabeledContent("Duration") {
                    TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                        Text(session.durationString(from: since))
                            .monospacedDigit()
                    }
                }
            }

            if let error = session.connectionError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        Section("Statistics") {
            LabeledContent("Messages") {
                Text("\(session.messages.count)")
                    .monospacedDigit()
            }

            LabeledContent("Subscriptions") {
                Text("\(session.subscriptions.count)")
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            if session.isConnected {
                Button {
                    session.reconnect()
                    dismiss()
                } label: {
                    Label("Reconnect", systemImage: "arrow.trianglehead.2.clockwise")
                }

                Button {
                    session.disconnect()
                    dismiss()
                } label: {
                    Label("Disconnect", systemImage: "bolt.slash")
                }
            } else if session.isReconnecting {
                Button {
                    session.cancelAutoReconnect()
                    dismiss()
                } label: {
                    Label("Cancel Reconnect", systemImage: "xmark.circle")
                }

                Button {
                    session.cancelAutoReconnect()
                    session.connect()
                    dismiss()
                } label: {
                    Label("Connect Now", systemImage: "bolt.fill")
                }
            } else if session.isConnecting {
                HStack {
                    Text("Connecting...")
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                Button {
                    session.connect()
                    dismiss()
                } label: {
                    Label("Connect", systemImage: "bolt.fill")
                }
            }

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("Clear All Messages", systemImage: "trash")
            }
            .disabled(session.messages.isEmpty)
            .confirmationDialog("Clear all messages?", isPresented: $showClearConfirmation) {
                Button("Clear All", role: .destructive) {
                    session.clearMessages()
                    dismiss()
                }
            }
        }
    }

}
#endif
