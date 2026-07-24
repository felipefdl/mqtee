//
//  MessageFilterBar.swift
//  mqtee
//

import SwiftUI

struct MessageFilterBar: View {
    @Binding var filter: MessageFilterState

    @State private var showFilters: Bool = false
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        HStack(spacing: 8) {
            searchField

            Button {
                showFilters.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: filter.activeFilterCount > 0
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                    if filter.activeFilterCount > 0 {
                        Text("\(filter.activeFilterCount)")
                            .font(.caption2.weight(.semibold))
                            .contentTransition(.numericText())
                    }
                }
            }
            .buttonStyle(.glass)
            .tint(filter.activeFilterCount > 0 ? .accentColor : nil)
            .controlSize(.small)
            .animation(BrandTheme.springSnappy, value: filter.activeFilterCount)
            #if os(macOS)
            .popover(isPresented: $showFilters) {
                MessageFilterPopover(filter: $filter)
            }
            #else
            .popover(isPresented: horizontalSizeClass == .regular ? $showFilters : .constant(false)) {
                MessageFilterPopover(filter: $filter)
            }
            .sheet(isPresented: horizontalSizeClass == .compact ? $showFilters : .constant(false)) {
                MessageFilterPopover(filter: $filter)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter messages...", text: $filter.payloadSearchText)
                .textFieldStyle(.plain)
            if !filter.payloadSearchText.isEmpty {
                Button {
                    filter.payloadSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
    }
}


