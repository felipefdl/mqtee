import SwiftUI

struct LogStatusBarView: View {
    var logStore: LogStore
    var connectionId: UUID
    var onTap: () -> Void

    var body: some View {
        if let entry = logStore.latestEntry(for: connectionId) {
            Divider()
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Image(systemName: entry.level.icon)
                        .foregroundStyle(entry.level.color)
                    Image(systemName: entry.category.icon)
                        .foregroundStyle(entry.category.color)
                    Text(entry.message)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let details = entry.details {
                        Text(details)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 200, alignment: .leading)
                    }
                    Spacer()
                    Text(entry.timestamp, format: .relative(presentation: .named))
                        .foregroundStyle(.secondary)
                }
                .font(.system(.caption, design: .monospaced))
                #if os(macOS)
                .padding(.horizontal, 20)
                #else
                .padding(.horizontal, 16)
                #endif
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial)
        }
    }
}
