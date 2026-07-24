//
//  SessionStore+StatusHelpers.swift
//  mqtee
//

import SwiftUI

extension SessionStore {
    var statusDotColor: Color {
        if isConnected { return .green }
        if isConnecting { return .yellow }
        if isReconnecting { return .orange }
        return .red
    }

    var statusLabel: String {
        if isConnected { return String(localized: "Connected", comment: "Connection status") }
        if isConnecting { return String(localized: "Connecting...", comment: "Connection status") }
        if isReconnecting { return String(localized: "Reconnecting...", comment: "Connection status") }
        return String(localized: "Disconnected", comment: "Connection status")
    }

    func durationString(from date: Date) -> String {
        let interval = Int(Date().timeIntervalSince(date))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60

        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
