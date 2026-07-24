//
//  SessionPersistenceService.swift
//  mqtee
//

import Foundation
import os

private let logger = Logger(subsystem: "app.mqtee", category: "SessionPersistence")

struct PersistedSession: Codable {
    let connectionId: UUID
    var subscriptions: [Subscription]
    var lastUpdated: Date

    init(connectionId: UUID, subscriptions: [Subscription] = []) {
        self.connectionId = connectionId
        self.subscriptions = subscriptions
        self.lastUpdated = Date()
    }
}

@MainActor
final class SessionPersistenceService {
    static let shared = SessionPersistenceService()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var pendingPublishTabs: [UUID: (tabs: [PublishTab], activeTabId: UUID?)] = [:]
    private var publishTabsFlushTask: Task<Void, Never>?

    private var sessionsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let sessionsDir = appSupport.appendingPathComponent("mqtee/\(StorageEnvironment.sessionsDirName)", isDirectory: true)
        try? fileManager.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        return sessionsDir
    }

    private init() {
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    private func sessionFileURL(for connectionId: UUID) -> URL {
        sessionsDirectory.appendingPathComponent("\(connectionId.uuidString).json")
    }

    private func publishTabsFileURL(for connectionId: UUID) -> URL {
        sessionsDirectory.appendingPathComponent("\(connectionId.uuidString)-publish-tabs.json")
    }

    func saveSession(_ session: PersistedSession) {
        let url = sessionFileURL(for: session.connectionId)
        do {
            let data = try encoder.encode(session)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to save session: \(error)")
        }
    }

    func loadSession(for connectionId: UUID) -> PersistedSession? {
        let url = sessionFileURL(for: connectionId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(PersistedSession.self, from: data)
        } catch {
            logger.error("Failed to load session: \(error)")
            return nil
        }
    }

    func deleteSession(for connectionId: UUID) {
        let url = sessionFileURL(for: connectionId)
        try? fileManager.removeItem(at: url)
        deletePublishTabs(for: connectionId)
    }

    func updateSubscriptions(for connectionId: UUID, subscriptions: [Subscription]) {
        var session = loadSession(for: connectionId) ?? PersistedSession(connectionId: connectionId)
        session.subscriptions = subscriptions
        session.lastUpdated = Date()
        saveSession(session)
    }

    // MARK: - Nonisolated Static Loaders

    nonisolated static func loadSessionData(for connectionId: UUID) -> PersistedSession? {
        let fileManager = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = appSupport
            .appendingPathComponent("mqtee/\(StorageEnvironment.sessionsDirName)", isDirectory: true)
            .appendingPathComponent("\(connectionId.uuidString).json")

        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(PersistedSession.self, from: data)
        } catch {
            logger.error("Failed to load session data: \(error)")
            return nil
        }
    }

    nonisolated static func loadPublishTabsData(for connectionId: UUID) -> PersistedPublishTabs? {
        let fileManager = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = appSupport
            .appendingPathComponent("mqtee/\(StorageEnvironment.sessionsDirName)", isDirectory: true)
            .appendingPathComponent("\(connectionId.uuidString)-publish-tabs.json")

        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(PersistedPublishTabs.self, from: data)
        } catch {
            logger.error("Failed to load publish tabs data: \(error)")
            return nil
        }
    }

    // MARK: - Publish Tabs

    func savePublishTabs(for connectionId: UUID, tabs: [PublishTab], activeTabId: UUID?) {
        pendingPublishTabs[connectionId] = (tabs: tabs, activeTabId: activeTabId)
        schedulePublishTabsFlush()
    }

    func loadPublishTabs(for connectionId: UUID) -> PersistedPublishTabs? {
        let url = publishTabsFileURL(for: connectionId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(PersistedPublishTabs.self, from: data)
        } catch {
            logger.error("Failed to load publish tabs: \(error)")
            return nil
        }
    }

    func deletePublishTabs(for connectionId: UUID) {
        pendingPublishTabs.removeValue(forKey: connectionId)
        let url = publishTabsFileURL(for: connectionId)
        try? fileManager.removeItem(at: url)
    }

    func flushPublishTabs() {
        publishTabsFlushTask?.cancel()
        publishTabsFlushTask = nil
        flushPendingPublishTabs()
    }

    private func schedulePublishTabsFlush() {
        publishTabsFlushTask?.cancel()
        publishTabsFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.flushPendingPublishTabs()
        }
    }

    private func flushPendingPublishTabs() {
        for (connectionId, pending) in pendingPublishTabs {
            var persisted = PersistedPublishTabs(
                connectionId: connectionId,
                tabs: pending.tabs,
                activeTabId: pending.activeTabId
            )
            persisted.lastUpdated = Date()
            let url = publishTabsFileURL(for: connectionId)
            do {
                let data = try encoder.encode(persisted)
                try data.write(to: url, options: .atomic)
            } catch {
                logger.error("Failed to save publish tabs: \(error)")
            }
        }
        pendingPublishTabs.removeAll()
    }

    // MARK: - Delete All

    func deleteAllSessions() {
        publishTabsFlushTask?.cancel()
        publishTabsFlushTask = nil
        pendingPublishTabs.removeAll()

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let sessionsDir = appSupport.appendingPathComponent("mqtee/\(StorageEnvironment.sessionsDirName)", isDirectory: true)
        try? fileManager.removeItem(at: sessionsDir)
    }

    // MARK: - Flush All

    func flush() {
        flushPublishTabs()
    }
}
