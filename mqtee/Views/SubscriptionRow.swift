import SwiftUI

struct SubscriptionRow: View {
    var subscription: Subscription
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(subscription.color.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                if subscription.topic.isEmpty {
                    Text("(empty topic)")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                } else {
                    Text(subscription.topic)
                        .font(.body)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text("QoS \(subscription.qos.rawValue)")

                    if subscription.noLocal {
                        Text("No Local")
                    }

                    if subscription.retainAsPublished {
                        Text("RAP")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

extension QoSLevel {
    var description: String {
        switch self {
        case .atMostOnce: return "At most once"
        case .atLeastOnce: return "At least once"
        case .exactlyOnce: return "Exactly once"
        }
    }
}
