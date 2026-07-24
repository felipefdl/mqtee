import SwiftUI

struct ConnectionStatusPopover: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: SessionStore
    @State private var showClearConfirmation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            infoSection
            Divider()
            actionsSection
        }
        .frame(width: 240)
    }

    // MARK: - Info Section

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(session.statusDotColor)
                    .frame(width: 8, height: 8)
                    .animation(BrandTheme.springSnappy, value: session.isConnected)
                Text(session.statusLabel)
                    .font(.headline)
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
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Divider()

            LabeledContent("Messages") {
                Text("\(session.messages.count)")
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }

            LabeledContent("Subscriptions") {
                Text("\(session.subscriptions.count)")
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }
        }
        .font(.callout)
        .padding(12)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 6) {
            if session.isConnected {
                Button {
                    session.reconnect()
                    dismiss()
                } label: {
                    Label("Reconnect", systemImage: "arrow.trianglehead.2.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.small)

                Button {
                    session.disconnect()
                    dismiss()
                } label: {
                    Label("Disconnect", systemImage: "bolt.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            } else if session.isReconnecting {
                Button {
                    session.cancelAutoReconnect()
                    dismiss()
                } label: {
                    Label("Cancel Reconnect", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.small)

                Button {
                    session.cancelAutoReconnect()
                    session.connect()
                    dismiss()
                } label: {
                    Label("Connect Now", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
            } else if session.isConnecting {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else {
                Button {
                    session.connect()
                    dismiss()
                } label: {
                    Label("Connect", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
            }
            Divider()

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("Clear All Messages", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(session.messages.isEmpty)
            .confirmationDialog("Clear all messages?", isPresented: $showClearConfirmation) {
                Button("Clear All", role: .destructive) {
                    session.clearMessages()
                    dismiss()
                }
            }
        }
        .padding(12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

}

#Preview("Connected") {
    ConnectionStatusPopover(session: SessionStore.preview())
        .padding()
}

#Preview("Disconnected") {
    let store = SessionStore.preview()
    store.isConnected = false
    store.connectedSince = nil
    return ConnectionStatusPopover(session: store)
        .padding()
}
