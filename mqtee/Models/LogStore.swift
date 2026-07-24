//
//  LogStore.swift
//  mqtee
//

import Foundation

@MainActor
@Observable
final class LogStore {
    static let shared = LogStore()

    private(set) var entries: [LogEntry] = []
    private(set) var latestEntryByConnection: [UUID: LogEntry] = [:]
    var maxEntries: Int = 1000

    private init() {}

    func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        details: String? = nil,
        topic: String? = nil,
        direction: PacketDirection? = nil,
        connectionId: UUID? = nil
    ) {
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            details: details,
            topic: topic,
            direction: direction,
            connectionId: connectionId
        )
        entries.append(entry)

        if let connectionId {
            latestEntryByConnection[connectionId] = entry
        }

        // Trim old entries if exceeding max
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func latestEntry(for connectionId: UUID) -> LogEntry? {
        latestEntryByConnection[connectionId]
    }

    func clear() {
        entries.removeAll()
        latestEntryByConnection.removeAll()
    }

    // MARK: - Convenience Methods

    func logConnection(
        _ message: String,
        level: LogLevel = .info,
        details: String? = nil,
        direction: PacketDirection? = nil,
        connectionId: UUID? = nil
    ) {
        log(level: level, category: .connection, message: message, details: details, direction: direction, connectionId: connectionId)
    }

    func logSubscription(
        _ message: String,
        level: LogLevel = .info,
        topic: String? = nil,
        details: String? = nil,
        direction: PacketDirection? = nil,
        connectionId: UUID? = nil
    ) {
        log(level: level, category: .subscription, message: message, details: details, topic: topic, direction: direction, connectionId: connectionId)
    }

    func logPublish(
        _ message: String,
        level: LogLevel = .info,
        topic: String? = nil,
        details: String? = nil,
        direction: PacketDirection? = nil,
        connectionId: UUID? = nil
    ) {
        log(level: level, category: .publish, message: message, details: details, topic: topic, direction: direction, connectionId: connectionId)
    }

    func logMessage(
        _ message: String,
        level: LogLevel = .debug,
        topic: String? = nil,
        details: String? = nil,
        direction: PacketDirection? = nil,
        connectionId: UUID? = nil
    ) {
        log(level: level, category: .message, message: message, details: details, topic: topic, direction: direction, connectionId: connectionId)
    }

    func logError(
        _ message: String,
        details: String? = nil,
        connectionId: UUID? = nil
    ) {
        log(level: .error, category: .error, message: message, details: details, connectionId: connectionId)
    }
}
