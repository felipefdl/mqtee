//
//  MessageFilterState.swift
//  mqtee
//

import Foundation

enum TimeRangeFilter: String, CaseIterable {
    case all
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case sixHours

    var label: String {
        switch self {
        case .all: return "All"
        case .oneMinute: return "1m"
        case .fiveMinutes: return "5m"
        case .fifteenMinutes: return "15m"
        case .thirtyMinutes: return "30m"
        case .oneHour: return "1h"
        case .sixHours: return "6h"
        }
    }

    func cutoffDate(from now: Date) -> Date? {
        switch self {
        case .all: return nil
        case .oneMinute: return now.addingTimeInterval(-60)
        case .fiveMinutes: return now.addingTimeInterval(-300)
        case .fifteenMinutes: return now.addingTimeInterval(-900)
        case .thirtyMinutes: return now.addingTimeInterval(-1800)
        case .oneHour: return now.addingTimeInterval(-3600)
        case .sixHours: return now.addingTimeInterval(-21600)
        }
    }
}

struct MessageFilterState: Equatable {
    var payloadSearchText: String = ""
    var selectedQoSLevels: Set<QoSLevel> = Set(QoSLevel.allCases)
    var showRetained: Bool? = nil
    var showSentByMe: Bool? = nil
    var timeRange: TimeRangeFilter = .all

    var isActive: Bool {
        !payloadSearchText.isEmpty
            || selectedQoSLevels.count != QoSLevel.allCases.count
            || showRetained != nil
            || showSentByMe != nil
            || timeRange != .all
    }

    var activeFilterCount: Int {
        var count = 0
        if !payloadSearchText.isEmpty { count += 1 }
        if selectedQoSLevels.count != QoSLevel.allCases.count { count += 1 }
        if showRetained != nil { count += 1 }
        if showSentByMe != nil { count += 1 }
        if timeRange != .all { count += 1 }
        return count
    }

    mutating func reset() {
        payloadSearchText = ""
        selectedQoSLevels = Set(QoSLevel.allCases)
        showRetained = nil
        showSentByMe = nil
        timeRange = .all
    }

    func apply(to messages: [MQTTMessage]) -> [MQTTMessage] {
        let now = Date()
        return messages.filter { message in
            // QoS (cheapest)
            guard selectedQoSLevels.contains(message.qos) else { return false }

            // Retained
            if let showRetained {
                guard message.retained == showRetained else { return false }
            }

            // Direction
            if let showSentByMe {
                guard message.sentByMe == showSentByMe else { return false }
            }

            // Timestamp
            if let cutoff = timeRange.cutoffDate(from: now) {
                guard message.timestamp >= cutoff else { return false }
            }

            // Payload search (most expensive)
            if !payloadSearchText.isEmpty {
                let search = payloadSearchText.lowercased()
                let matchesTopic = message.topic.lowercased().contains(search)
                let matchesPayload = message.payloadString.lowercased().contains(search)
                guard matchesTopic || matchesPayload else { return false }
            }

            return true
        }
    }
}
