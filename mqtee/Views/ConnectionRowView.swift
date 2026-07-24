//
//  ConnectionRowView.swift
//  mqtee
//

import SwiftUI

struct ConnectionRowView: View {
    let connection: Connection
    let folderColor: Color?

    private var faviconService: FaviconService { FaviconService.shared }

    var body: some View {
        HStack(spacing: 12) {
            // Connection icon
            Group {
                if let iconImage = faviconService.loadedIcons[connection.id] {
                    Image(platformImage: iconImage)
                        .resizable()
                        .interpolation(.high)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(folderColor ?? .gray)

                        Image(systemName: "server.rack")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 36, height: 36)

            // Connection info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(connection.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    if connection.useTLS {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(connection.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        ConnectionRowView(
            connection: Connection(name: "Local Broker", host: "localhost", port: 1883),
            folderColor: .blue
        )
        ConnectionRowView(
            connection: Connection(name: "Production", host: "mqtt.example.com", port: 8883, username: "admin", useTLS: true),
            folderColor: .red
        )
    }
    .frame(width: 300)
    .padding()
}
