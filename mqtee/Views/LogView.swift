//
//  LogView.swift
//  mqtee
//

import SwiftUI

struct EventLogWindowValue: Codable, Hashable {
    let connectionId: UUID
    let connectionName: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(connectionId)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.connectionId == rhs.connectionId
    }
}

struct LogView: View {
    var logStore: LogStore
    var connectionId: UUID?

    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    @State private var selectedCategories: Set<LogCategory> = Set(LogCategory.allCases)
    @State private var selectedDirections: Set<PacketDirection> = Set(PacketDirection.allCases)
    @State private var autoScroll: Bool = true
    @State private var showFilters: Bool = false
    @State private var cachedFilteredEntries: [LogEntry] = []
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

    private func recomputeFilteredEntries() {
        cachedFilteredEntries = logStore.entries.filter { entry in
            if let connectionId, entry.connectionId != nil && entry.connectionId != connectionId {
                return false
            }
            guard selectedLevels.contains(entry.level) else { return false }
            guard selectedCategories.contains(entry.category) else { return false }
            if let direction = entry.direction {
                guard selectedDirections.contains(direction) else { return false }
            }
            if !debouncedSearchText.isEmpty {
                let searchLower = debouncedSearchText.lowercased()
                let matches = entry.message.lowercased().contains(searchLower) ||
                    (entry.topic?.lowercased().contains(searchLower) ?? false) ||
                    (entry.details?.lowercased().contains(searchLower) ?? false)
                if !matches { return false }
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            Divider()
            logListView
        }
        .onAppear {
            recomputeFilteredEntries()
        }
        .onChange(of: logStore.entries.count) {
            recomputeFilteredEntries()
        }
        .onChange(of: selectedLevels) {
            recomputeFilteredEntries()
        }
        .onChange(of: selectedCategories) {
            recomputeFilteredEntries()
        }
        .onChange(of: selectedDirections) {
            recomputeFilteredEntries()
        }
        .onChange(of: debouncedSearchText) {
            recomputeFilteredEntries()
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                debouncedSearchText = newValue
            }
        }
        .onDisappear {
            searchDebounceTask?.cancel()
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter logs...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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

    private var toolbarView: some View {
        VStack(spacing: 6) {
            searchField
            if isCompact {
                compactToolbarButtons
            } else {
                regularToolbarButtons
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var compactToolbarButtons: some View {
        HStack(spacing: 8) {
            Button {
                showFilters.toggle()
            } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .popover(isPresented: $showFilters) {
                LogFilterPopover(
                    selectedLevels: $selectedLevels,
                    selectedCategories: $selectedCategories,
                    selectedDirections: $selectedDirections
                )
            }

            Toggle(isOn: $autoScroll) {
                Label("Auto-scroll", systemImage: "chevron.down.2")
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)

            Button {
                logStore.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)

            Spacer()

            Text("\(cachedFilteredEntries.count) / \(logStore.entries.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var regularToolbarButtons: some View {
        HStack(spacing: 12) {
            Button {
                showFilters.toggle()
            } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.glass)
            .popover(isPresented: $showFilters) {
                LogFilterPopover(
                    selectedLevels: $selectedLevels,
                    selectedCategories: $selectedCategories,
                    selectedDirections: $selectedDirections
                )
            }

            Spacer()

            Toggle(isOn: $autoScroll) {
                Label("Auto-scroll", systemImage: "chevron.down.2")
            }
            .toggleStyle(.button)
            .buttonStyle(.glass)
            .fixedSize()

            Button {
                logStore.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.glass)

            Text("\(cachedFilteredEntries.count) / \(logStore.entries.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var logListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(cachedFilteredEntries) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 16))
                }
            }
            .listStyle(.plain)
            .font(.system(.caption, design: .monospaced))
            .onChange(of: cachedFilteredEntries.count) { oldCount, newCount in
                if newCount > oldCount, autoScroll, let lastEntry = cachedFilteredEntries.last {
                    withAnimation {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview("Log View") {
    let store = LogStore.shared
    Task { @MainActor in
        store.logConnection("Connecting to broker", details: "host: localhost, port: 1883")
        store.logConnection("Connected successfully", level: .info)
        store.logSubscription("Subscribed", topic: "sensors/#", details: "QoS: 1")
        store.logSubscription("Subscribed", topic: "home/+/temperature")
        store.logMessage("Received message", topic: "sensors/living-room/temp", details: "{\"value\": 22.5}")
        store.logPublish("Published message", topic: "control/light", details: "{\"state\": \"on\"}")
        store.logError("Connection lost", details: "Broker closed connection unexpectedly")
        store.logConnection("Reconnecting...", level: .warning)
        store.logConnection("Reconnected")
    }
    return LogView(logStore: store)
        .frame(width: 800, height: 400)
}
