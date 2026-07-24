//
//  LogFilterPopover.swift
//  mqtee
//

import SwiftUI

struct LogFilterPopover: View {
    @Binding var selectedLevels: Set<LogLevel>
    @Binding var selectedCategories: Set<LogCategory>
    @Binding var selectedDirections: Set<PacketDirection>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filters")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Log Levels")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        FilterChip(
                            label: level.localizedName,
                            icon: level.icon,
                            color: level.color,
                            isSelected: selectedLevels.contains(level)
                        ) {
                            if selectedLevels.contains(level) {
                                selectedLevels.remove(level)
                            } else {
                                selectedLevels.insert(level)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Categories")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(LogCategory.allCases, id: \.self) { category in
                        FilterChip(
                            label: category.localizedName,
                            icon: category.icon,
                            color: category.color,
                            isSelected: selectedCategories.contains(category)
                        ) {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Direction")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    FilterChip(
                        label: "Incoming",
                        icon: "arrow.down.left",
                        color: .green,
                        isSelected: selectedDirections.contains(.incoming)
                    ) {
                        if selectedDirections.contains(.incoming) {
                            selectedDirections.remove(.incoming)
                        } else {
                            selectedDirections.insert(.incoming)
                        }
                    }

                    FilterChip(
                        label: "Outgoing",
                        icon: "arrow.up.right",
                        color: .blue,
                        isSelected: selectedDirections.contains(.outgoing)
                    ) {
                        if selectedDirections.contains(.outgoing) {
                            selectedDirections.remove(.outgoing)
                        } else {
                            selectedDirections.insert(.outgoing)
                        }
                    }
                }
            }

            HStack {
                Button("Select All") {
                    selectedLevels = Set(LogLevel.allCases)
                    selectedCategories = Set(LogCategory.allCases)
                    selectedDirections = Set(PacketDirection.allCases)
                }
                .buttonStyle(.glass)

                Button("Clear All") {
                    selectedLevels = []
                    selectedCategories = []
                    selectedDirections = []
                }
                .buttonStyle(.glass)
            }
        }
        .padding()
        #if os(macOS)
        .frame(width: 400)
        #else
        .frame(maxWidth: 400)
        #endif
    }
}
