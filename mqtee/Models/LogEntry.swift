//
//  LogEntry.swift
//  mqtee
//

import Foundation
import SwiftUI

enum LogLevel: String, CaseIterable, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    var localizedName: String {
        rawValue
    }

    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
}

enum LogCategory: String, CaseIterable, Codable {
    case connection = "Connection"
    case subscription = "Subscription"
    case publish = "Publish"
    case message = "Message"
    case keepAlive = "Keep Alive"
    case error = "Error"

    var localizedName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .connection: return "server.rack"
        case .subscription: return "antenna.radiowaves.left.and.right"
        case .publish: return "paperplane"
        case .message: return "envelope"
        case .keepAlive: return "arrow.up.arrow.down"
        case .error: return "exclamationmark.octagon"
        }
    }

    var color: Color {
        switch self {
        case .connection: return .green
        case .subscription: return .purple
        case .publish: return .blue
        case .message: return .cyan
        case .keepAlive: return .mint
        case .error: return .red
        }
    }
}

enum PacketDirection: String, CaseIterable, Codable {
    case incoming = "Incoming"
    case outgoing = "Outgoing"
}

struct LogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let details: String?
    let topic: String?
    let direction: PacketDirection?
    let connectionId: UUID?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        category: LogCategory,
        message: String,
        details: String? = nil,
        topic: String? = nil,
        direction: PacketDirection? = nil,
        connectionId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.details = details
        self.topic = topic
        self.direction = direction
        self.connectionId = connectionId
    }
}
