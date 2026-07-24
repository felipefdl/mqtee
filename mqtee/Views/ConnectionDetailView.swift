//
//  ConnectionDetailView.swift
//  mqtee
//

import SwiftUI

struct ConnectionDetailView: View {
    let connection: Connection
    var onConnect: (Connection) -> Void
    var onEdit: (Connection) -> Void

    private var faviconService: FaviconService { FaviconService.shared }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // Connection header
                VStack(spacing: 12) {
                    if let iconImage = faviconService.loadedIcons[connection.id] {
                        Image(platformImage: iconImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .primary.opacity(0.2), radius: 8, y: 4)
                    } else {
                        Image(systemName: "server.rack")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                            .frame(width: 48, height: 48)
                    }

                    Text(connection.name)
                        .font(.title)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(connection.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(connection.mqttVersion.displayName, systemImage: "number")
                        if connection.useTLS {
                            Label("TLS", systemImage: "lock.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .padding(24)

                // Active warning (always reserves space)
                HStack(spacing: 6) {
                    Label("Active in another window", systemImage: "macwindow.on.rectangle")
                    Button("Reset") {
                        ActiveConnectionTracker.shared.release(connection.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .opacity(ActiveConnectionTracker.shared.isActive(connection.id) ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.5), value: ActiveConnectionTracker.shared.isActive(connection.id))
                .padding(.top, 12)

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: { onEdit(connection) }) {
                        Label("Edit", systemImage: "pencil")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                    Button(action: { onConnect(connection) }) {
                        Label("Connect", systemImage: "bolt.fill")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(ActiveConnectionTracker.shared.isActive(connection.id))
                }
                .padding(.top, 12)

                // Connection details
                connectionDetails
                    .padding(.top, 28)
            }
            .frame(width: 320)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(connection.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { onEdit(connection) }) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(action: { onConnect(connection) }) {
                    Label("Connect", systemImage: "bolt.fill")
                }
                .buttonStyle(.glassProminent)
                .disabled(ActiveConnectionTracker.shared.isActive(connection.id))
                .help(ActiveConnectionTracker.shared.isActive(connection.id)
                    ? String(localized: "Active in another window", comment: "Tooltip when connection is active elsewhere")
                    : String(localized: "Connect to broker", comment: "Tooltip for connect button"))
            }
        }
    }

    private var connectionDetails: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            if let lastConnected = connection.lastConnectedAt {
                detailRow("Last Connected", value: lastConnected.formatted(.relative(presentation: .named)))
            } else {
                detailRow("Last Connected", value: "Never")
            }

            if let created = connection.createdAt {
                detailRow("Created", value: created.formatted(date: .abbreviated, time: .omitted))
            }

            Divider()
                .gridCellColumns(2)

            detailRow("Client ID", value: MQTTService.deviceClientId(for: connection.id))
            detailRow("Keep Alive", value: "\(connection.keepAlive)s")
            detailRow("Clean Session", value: connection.cleanSession ? "Yes" : "No")

            if connection.mqttVersion == .v5, let expiry = connection.sessionExpiry {
                detailRow("Session Expiry", value: "\(expiry)s")
            }

            if connection.lastWill.enabled {
                detailRow("Last Will", value: connection.lastWill.topic)
            }

            if connection.persistSession {
                detailRow("Session", value: "Persistent")
            }
        }
        .font(.callout)
        .frame(width: 300)
    }

    @ViewBuilder
    private func detailRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .gridColumnAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
