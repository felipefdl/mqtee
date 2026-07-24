//
//  ImportExportService.swift
//  mqtee
//

import Foundation
import UniformTypeIdentifiers

enum ImportExportService {

    // MARK: - Import Result

    struct ImportResult: Identifiable {
        let document: ExportDocument
        let fileURL: URL

        var id: String { fileURL.absoluteString }
    }

    // MARK: - Export (Data Preparation)

    static func prepareExportData(
        _ connections: [Connection],
        folders: [ConnectionFolder],
        includeCredentials: Bool
    ) -> Data? {
        let exportedConnections = connections.map { connection -> ExportedConnection in
            var credentials: ConnectionCredentials?
            if includeCredentials {
                credentials = try? KeychainService.shared.loadCredentials(for: connection.id)
            }
            return ExportedConnection(connection: connection, credentials: credentials)
        }

        // Filter folders to only those referenced by exported connections
        let referencedFolderIds = Set(connections.compactMap(\.folderId))
        let exportedFolders = folders.filter { referencedFolderIds.contains($0.id) }

        let document = ExportDocument(folders: exportedFolders, connections: exportedConnections)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try? encoder.encode(document)
    }

    // MARK: - Import (File Parsing)

    static func parseImportFile(at url: URL) -> ImportResult? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let document = try? decoder.decode(ExportDocument.self, from: data) else { return nil }

        return ImportResult(document: document, fileURL: url)
    }

    // MARK: - Import (Perform)

    @MainActor
    static func performImport(
        document: ExportDocument,
        store: ConnectionStore,
        importCredentials: Bool,
        folderStrategy: FolderImportStrategy
    ) -> Int {
        // Build folder ID mapping based on strategy
        let folderMapping = buildFolderMapping(
            importedFolders: document.folders,
            store: store,
            strategy: folderStrategy
        )

        var importedCount = 0
        var newConnections: [(id: UUID, host: String)] = []

        for exported in document.connections {
            let oldConnection = exported.connection
            let newId = UUID()

            // Map folderId based on strategy
            var newFolderId: UUID?
            if let oldFolderId = oldConnection.folderId {
                newFolderId = folderMapping[oldFolderId]
            }

            let newConnection = Connection(
                id: newId,
                name: oldConnection.name,
                host: oldConnection.host,
                port: oldConnection.port,
                folderId: newFolderId,
                mqttVersion: oldConnection.mqttVersion,
                clientId: "mqtee-\(UUID().uuidString.prefix(8))",
                cleanSession: oldConnection.cleanSession,
                keepAlive: oldConnection.keepAlive,
                sessionExpiry: oldConnection.sessionExpiry,
                username: oldConnection.username,
                useTLS: oldConnection.useTLS,
                useClientCertificate: oldConnection.useClientCertificate,
                allowInsecureTLS: oldConnection.allowInsecureTLS,
                lastWill: oldConnection.lastWill,
                persistSession: oldConnection.persistSession,
                createdAt: Date(),
                lastConnectedAt: nil
            )

            store.addConnection(newConnection)
            MQTTService.setDeviceClientId(newConnection.clientId, for: newId)
            store.publishDeviceClientId(newConnection.clientId, for: newId)
            newConnections.append((id: newId, host: newConnection.host))

            // Import credentials if requested and available
            if importCredentials, let credentials = exported.credentials {
                try? KeychainService.shared.saveCredentials(credentials, for: newId)
            }

            importedCount += 1
        }

        // Fetch favicons for imported connections
        for conn in newConnections {
            Task {
                await FaviconService.shared.fetchFavicon(for: conn.id, host: conn.host)
            }
        }

        return importedCount
    }

    // MARK: - Folder Mapping

    private static func buildFolderMapping(
        importedFolders: [ConnectionFolder],
        store: ConnectionStore,
        strategy: FolderImportStrategy
    ) -> [UUID: UUID] {
        var mapping: [UUID: UUID] = [:]

        switch strategy {
        case .flatten:
            // All connections become unfoldered -- no mapping needed
            break

        case .mergeByName:
            for folder in importedFolders {
                if let existing = store.folders.first(where: { $0.name == folder.name }) {
                    mapping[folder.id] = existing.id
                } else {
                    let newFolder = ConnectionFolder(name: folder.name, color: folder.color)
                    store.addFolder(newFolder)
                    mapping[folder.id] = newFolder.id
                }
            }

        case .recreate:
            for folder in importedFolders {
                let newFolder = ConnectionFolder(name: folder.name, color: folder.color)
                store.addFolder(newFolder)
                mapping[folder.id] = newFolder.id
            }
        }

        return mapping
    }
}
