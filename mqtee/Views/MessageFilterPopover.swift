//
//  MessageFilterPopover.swift
//  mqtee
//

import SwiftUI

struct MessageFilterPopover: View {
    @Binding var filter: MessageFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filters")
                .font(.headline)

            // QoS Level
            VStack(alignment: .leading, spacing: 8) {
                Text("QoS Level")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(QoSLevel.allCases, id: \.self) { level in
                        FilterChip(
                            label: "QoS \(level.rawValue)",
                            icon: "circle.fill",
                            color: qosColor(level),
                            isSelected: filter.selectedQoSLevels.contains(level)
                        ) {
                            if filter.selectedQoSLevels.contains(level) {
                                filter.selectedQoSLevels.remove(level)
                            } else {
                                filter.selectedQoSLevels.insert(level)
                            }
                        }
                    }
                }
            }

            // Direction
            VStack(alignment: .leading, spacing: 8) {
                Text("Direction")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    FilterChip(
                        label: "Received",
                        icon: "arrow.down.left",
                        color: .green,
                        isSelected: filter.showSentByMe == nil || filter.showSentByMe == false
                    ) {
                        toggleDirection(sentByMe: false)
                    }

                    FilterChip(
                        label: "Sent",
                        icon: "arrow.up.right",
                        color: .blue,
                        isSelected: filter.showSentByMe == nil || filter.showSentByMe == true
                    ) {
                        toggleDirection(sentByMe: true)
                    }
                }
            }

            // Retained
            VStack(alignment: .leading, spacing: 8) {
                Text("Retained")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    FilterChip(
                        label: "Retained",
                        icon: "pin.fill",
                        color: .orange,
                        isSelected: filter.showRetained == nil || filter.showRetained == true
                    ) {
                        toggleRetained(retained: true)
                    }

                    FilterChip(
                        label: "Not Retained",
                        icon: "pin.slash",
                        color: .secondary,
                        isSelected: filter.showRetained == nil || filter.showRetained == false
                    ) {
                        toggleRetained(retained: false)
                    }
                }
            }

            // Time Range
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Range")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(TimeRangeFilter.allCases, id: \.self) { range in
                        FilterChip(
                            label: range.label,
                            icon: "clock",
                            color: .purple,
                            isSelected: filter.timeRange == range
                        ) {
                            filter.timeRange = range
                        }
                    }
                }
            }

            Button("Reset All") {
                filter.reset()
            }
            .buttonStyle(.glass)
        }
        .padding()
        #if os(macOS)
        .frame(width: 340)
        #else
        .frame(maxWidth: 360)
        #endif
    }

    private func qosColor(_ level: QoSLevel) -> Color {
        switch level {
        case .atMostOnce: return .green
        case .atLeastOnce: return .orange
        case .exactlyOnce: return .red
        }
    }

    private func toggleDirection(sentByMe: Bool) {
        switch filter.showSentByMe {
        case nil:
            // Both selected -> deselect this one (show only the other)
            filter.showSentByMe = !sentByMe
        case sentByMe:
            // Only this one selected -> can't deselect both, reset to all
            filter.showSentByMe = nil
        default:
            // Other one selected -> reset to all
            filter.showSentByMe = nil
        }
    }

    private func toggleRetained(retained: Bool) {
        switch filter.showRetained {
        case nil:
            // Both selected -> deselect this one (show only the other)
            filter.showRetained = !retained
        case retained:
            // Only this one selected -> can't deselect both, reset to all
            filter.showRetained = nil
        default:
            // Other one selected -> reset to all
            filter.showRetained = nil
        }
    }
}
