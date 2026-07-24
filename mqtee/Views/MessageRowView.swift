import SwiftUI

enum MessageListDensity: String, CaseIterable {
    case compact
    case comfortable
}

struct MessageRowView: View, Equatable {
    var message: MQTTMessage
    var color: Color = .secondary
    var payloadLineLimit: Int = 2

    static func == (lhs: MessageRowView, rhs: MessageRowView) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.color == rhs.color &&
        lhs.payloadLineLimit == rhs.payloadLineLimit
    }

    var body: some View {
        VStack(alignment: message.sentByMe ? .trailing : .leading, spacing: 4) {
            Text(message.topic)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(message.cachedPayloadPreview)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(payloadLineLimit)
                .multilineTextAlignment(message.sentByMe ? .trailing : .leading)

            HStack(spacing: 0) {
                if message.sentByMe {
                    Image(systemName: "paperplane.fill")
                        .font(.caption2)
                    Text(" \u{00B7} ")
                    Text(message.qos.shortName)
                    if message.retained {
                        Text(" \u{00B7} Retained")
                    }
                    Text(" \u{00B7} \(message.formattedSize)")
                    Text(" \u{00B7} \(message.formattedTime)")
                } else {
                    Text(message.formattedTime)
                    Text(" \u{00B7} \(message.formattedSize)")
                    if message.retained {
                        Text(" \u{00B7} Retained")
                    }
                    Text(" \u{00B7} ")
                    Text(message.qos.shortName)
                }
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: message.sentByMe ? .trailing : .leading)
        .padding(.vertical, 4)
        .listRowBackground(message.sentByMe ? color.opacity(0.06) : nil)
        .listRowSeparator(message.sentByMe ? .hidden : .automatic)
    }
}
