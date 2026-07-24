//
//  LogEntryRow.swift
//  mqtee
//

import SwiftUI

struct LogEntryRow: View {
    var entry: LogEntry
    @State private var isExpanded: Bool = false
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var isCompact: Bool {
        #if os(macOS)
        return false
        #else
        return horizontalSizeClass == .compact
        #endif
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isCompact {
                compactRow
            } else {
                regularRow
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if entry.details != nil {
                withAnimation(BrandTheme.springSnappy) {
                    isExpanded.toggle()
                }
            }
        }
    }

    private var regularRow: some View {
        Group {
            HStack(spacing: 8) {
                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)

                if let direction = entry.direction {
                    Image(systemName: direction == .incoming ? "arrow.down.left" : "arrow.up.right")
                        .foregroundStyle(direction == .incoming ? .green : .blue)
                        .frame(width: 16)
                } else {
                    Color.clear
                        .frame(width: 16, height: 1)
                }

                Text(entry.message)
                    .foregroundStyle(entry.level.color)
                    .lineLimit(isExpanded ? nil : 1)

                if let details = entry.details {
                    Text(details)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 300, alignment: .leading)
                }

                Spacer()

                if let topic = entry.topic {
                    Text(topic)
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                }
            }

            if isExpanded, let details = entry.details {
                Text(details)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 108)
                    .textSelection(.enabled)
            }
        }
    }

    private var compactRow: some View {
        Group {
            HStack(spacing: 6) {
                Text(Self.shortTimeFormatter.string(from: entry.timestamp))
                    .foregroundStyle(.secondary)
                    .frame(width: 62, alignment: .leading)

                if let direction = entry.direction {
                    Image(systemName: direction == .incoming ? "arrow.down.left" : "arrow.up.right")
                        .foregroundStyle(direction == .incoming ? .green : .blue)
                        .frame(width: 14)
                } else {
                    Color.clear
                        .frame(width: 14, height: 1)
                }

                Text(entry.message)
                    .foregroundStyle(entry.level.color)
                    .lineLimit(isExpanded ? nil : 1)
            }

            if entry.details != nil || entry.topic != nil {
                HStack(spacing: 6) {
                    if let details = entry.details {
                        Text(details)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer()

                    if let topic = entry.topic {
                        Text(topic)
                            .foregroundStyle(.cyan)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 62 + 6 + 14 + 6)
            }

            if isExpanded, let details = entry.details {
                Text(details)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}
