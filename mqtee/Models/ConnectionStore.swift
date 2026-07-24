//
//  ConnectionStore.swift
//  mqtee
//

import Foundation
import SwiftUI

@MainActor
@Observable
class ConnectionStore {
    static let connectionsKey = "\(StorageEnvironment.keyPrefix)connections"
    static let foldersKey = "\(StorageEnvironment.keyPrefix)folders"

    let storage = UserDefaults.standard
    var iCloudAvailable: Bool = false
    var iCloud: NSUbiquitousKeyValueStore?
    var syncTimeoutTask: Task<Void, Never>?
    var isLoading = false
    let mockMode: Bool

    var isSyncing: Bool = false

    var connections: [Connection] = [] {
        didSet { if !mockMode { saveConnections() } }
    }

    var folders: [ConnectionFolder] = [] {
        didSet { if !mockMode { saveFolders() } }
    }

    init() {
        self.mockMode = false
        setup()
    }

    /// Creates a store with mock data that does not read from or write to persistent storage.
    static func mock(connections: [Connection] = [], folders: [ConnectionFolder] = []) -> ConnectionStore {
        let store = ConnectionStore(mockMode: true)
        store.connections = connections
        store.folders = folders
        return store
    }

    private init(mockMode: Bool) {
        self.mockMode = mockMode
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func connections(in folder: ConnectionFolder?) -> [Connection] {
        connections.filter { $0.folderId == folder?.id }
    }
    
    var sortedFolders: [ConnectionFolder] {
        folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var unfolderedConnections: [Connection] {
        connections.filter { $0.folderId == nil }
    }
    
    func addConnection(_ connection: Connection) {
        connections.append(connection)
    }
    
    func addFolder(_ folder: ConnectionFolder) {
        folders.append(folder)
    }
    
    func updateConnection(_ connection: Connection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        }
    }
    
    func deleteConnection(_ connection: Connection) {
        connections.removeAll { $0.id == connection.id }
        // Also delete credentials from Keychain
        try? KeychainService.shared.deleteCredentials(for: connection.id)
        // Clean up persisted session and publish tabs
        SessionPersistenceService.shared.deleteSession(for: connection.id)
        // Clean up device-local client ID
        MQTTService.removeDeviceClientId(for: connection.id)
        // Clean up iCloud device client ID mapping
        removeDeviceClientIdMapping(for: connection.id)
    }
    
    func deleteFolder(_ folder: ConnectionFolder) {
        // Move connections to unfoldered
        for i in connections.indices where connections[i].folderId == folder.id {
            connections[i].folderId = nil
        }
        folders.removeAll { $0.id == folder.id }
    }
    
    func updateFolder(_ folder: ConnectionFolder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
        }
    }
    
    func moveConnection(_ connection: Connection, to folder: ConnectionFolder?) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index].folderId = folder?.id
        }
    }

    func moveConnectionById(_ connectionId: UUID, toFolderId: UUID?) {
        guard let index = connections.firstIndex(where: { $0.id == connectionId }),
              connections[index].folderId != toFolderId else { return }
        connections[index].folderId = toFolderId
    }

    @discardableResult
    func duplicateConnection(_ connection: Connection) -> Connection {
        let baseName = connection.name
        let existingNames = Set(connections.map(\.name))
        var number = 2
        var candidateName = "\(baseName) (\(number))"
        while existingNames.contains(candidateName) {
            number += 1
            candidateName = "\(baseName) (\(number))"
        }

        let newId = UUID()
        let duplicate = Connection(
            id: newId,
            name: candidateName,
            host: connection.host,
            port: connection.port,
            folderId: connection.folderId,
            mqttVersion: connection.mqttVersion,
            clientId: "mqtee-\(UUID().uuidString.prefix(8))",
            cleanSession: connection.cleanSession,
            keepAlive: connection.keepAlive,
            sessionExpiry: connection.sessionExpiry,
            username: connection.username,
            useTLS: connection.useTLS,
            useClientCertificate: connection.useClientCertificate,
            allowInsecureTLS: connection.allowInsecureTLS,
            lastWill: connection.lastWill,
            persistSession: connection.persistSession,
            createdAt: Date(),
            lastConnectedAt: nil
        )

        if let credentials = try? KeychainService.shared.loadCredentials(for: connection.id) {
            try? KeychainService.shared.saveCredentials(credentials, for: newId)
        }

        addConnection(duplicate)
        MQTTService.setDeviceClientId(duplicate.clientId, for: newId)
        publishDeviceClientId(duplicate.clientId, for: newId)
        return duplicate
    }
    
}
