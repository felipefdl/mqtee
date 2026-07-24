//
//  ConnectionStore+Sync.swift
//  mqtee
//

import Foundation
import os

private let logger = Logger(subsystem: "app.mqtee", category: "ConnectionStore")

// MARK: - Setup

extension ConnectionStore {
    func setup() {
        setupStorage()
        load()
        startSyncTimeoutIfNeeded()
    }

    private func setupStorage() {
        if FileManager.default.ubiquityIdentityToken != nil {
            iCloud = NSUbiquitousKeyValueStore.default
            iCloudAvailable = iCloud?.synchronize() ?? false

            if iCloudAvailable {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(iCloudDidChange),
                    name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                    object: iCloud
                )
            }
        }

        if !iCloudAvailable {
            logger.info("iCloud not available, using local storage")
        }
    }
}

// MARK: - Cross-Device Client ID Tracking

extension ConnectionStore {
    func publishDeviceClientId(_ clientId: String, for connectionId: UUID) {
        guard let iCloud else { return }
        let key = "\(StorageEnvironment.keyPrefix)connDeviceClientIds.\(connectionId.uuidString)"
        var mapping = (iCloud.dictionary(forKey: key) as? [String: [String: String]]) ?? [:]
        mapping[MQTTService.currentDeviceId] = [
            "clientId": clientId,
            "name": MQTTService.currentDeviceName
        ]
        iCloud.set(mapping, forKey: key)
    }

    func deviceClientIdConflicts(for connectionId: UUID, clientId: String) -> [String] {
        guard let iCloud else { return [] }
        let key = "\(StorageEnvironment.keyPrefix)connDeviceClientIds.\(connectionId.uuidString)"
        guard let mapping = iCloud.dictionary(forKey: key) as? [String: [String: String]] else { return [] }
        let currentDevice = MQTTService.currentDeviceId
        return mapping.compactMap { deviceId, info in
            guard deviceId != currentDevice, info["clientId"] == clientId else { return nil }
            return info["name"] ?? deviceId
        }
    }

    func removeDeviceClientIdMapping(for connectionId: UUID) {
        guard let iCloud else { return }
        iCloud.removeObject(forKey: "\(StorageEnvironment.keyPrefix)connDeviceClientIds.\(connectionId.uuidString)")
    }
}

// MARK: - Reset All Data

extension ConnectionStore {
    func resetAllData() {
        if let iCloud {
            for connection in connections {
                iCloud.removeObject(forKey: "\(StorageEnvironment.keyPrefix)connDeviceClientIds.\(connection.id.uuidString)")
            }
            iCloud.removeObject(forKey: Self.connectionsKey)
            iCloud.removeObject(forKey: Self.foldersKey)
        }

        storage.removeObject(forKey: Self.connectionsKey)
        storage.removeObject(forKey: Self.foldersKey)

        isLoading = true
        connections = []
        folders = []
        isLoading = false
    }
}

// MARK: - Persistence

extension ConnectionStore {
    func synchronize() {
        iCloud?.synchronize()
    }

    func load() {
        isLoading = true
        loadConnections()
        loadFolders()
        isLoading = false
    }

    func saveConnections() {
        guard !isLoading else { return }
        do {
            let data = try JSONEncoder().encode(connections)
            if iCloudAvailable, let iCloud = iCloud {
                iCloud.set(data, forKey: Self.connectionsKey)
            }
            storage.set(data, forKey: Self.connectionsKey)
        } catch {
            logger.error("Failed to encode connections: \(error)")
        }
    }

    func saveFolders() {
        guard !isLoading else { return }
        do {
            let data = try JSONEncoder().encode(folders)
            if iCloudAvailable, let iCloud = iCloud {
                iCloud.set(data, forKey: Self.foldersKey)
            }
            storage.set(data, forKey: Self.foldersKey)
        } catch {
            logger.error("Failed to encode folders: \(error)")
        }
    }

    func startSyncTimeoutIfNeeded() {
        guard iCloudAvailable, connections.isEmpty else { return }
        isSyncing = true
        syncTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.isSyncing = false
        }
    }

    @objc nonisolated func iCloudDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.load()
            self.syncTimeoutTask?.cancel()
            self.isSyncing = false

            let faviconService = FaviconService.shared
            faviconService.loadAllIcons(for: self.connections.map(\.id))
            for connection in self.connections where faviconService.loadedIcons[connection.id] == nil {
                await faviconService.fetchFavicon(for: connection.id, host: connection.host)
            }
        }
    }
}

// MARK: - Private Persistence Helpers

private extension ConnectionStore {
    func loadConnections() {
        let data: Data?
        if iCloudAvailable, let iCloud = iCloud {
            data = iCloud.data(forKey: Self.connectionsKey)
        } else {
            data = storage.data(forKey: Self.connectionsKey)
        }

        guard let data = data else { return }
        do {
            connections = try JSONDecoder().decode([Connection].self, from: data)
        } catch {
            logger.error("Failed to decode connections: \(error)")
        }
    }

    func loadFolders() {
        let data: Data?
        if iCloudAvailable, let iCloud = iCloud {
            data = iCloud.data(forKey: Self.foldersKey)
        } else {
            data = storage.data(forKey: Self.foldersKey)
        }

        guard let data = data else { return }
        do {
            folders = try JSONDecoder().decode([ConnectionFolder].self, from: data)
        } catch {
            logger.error("Failed to decode folders: \(error)")
        }
    }
}
