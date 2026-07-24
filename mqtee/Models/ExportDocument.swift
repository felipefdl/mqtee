//
//  ExportDocument.swift
//  mqtee
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - UTType Extension

extension UTType {
    static let mqteeExport = UTType(exportedAs: "app.mqtee.export", conformingTo: .json)
}

// MARK: - Export Document

struct ExportDocument: Codable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let appVersion: String
    let folders: [ConnectionFolder]
    let connections: [ExportedConnection]

    init(folders: [ConnectionFolder], connections: [ExportedConnection]) {
        self.version = Self.currentVersion
        self.exportedAt = Date()
        self.appVersion = Bundle.main.appVersion
        self.folders = folders
        self.connections = connections
    }
}

// MARK: - Export File Document (for .fileExporter)

struct MQTeeExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.mqteeExport] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Exported Connection

struct ExportedConnection: Codable {
    let connection: Connection
    let credentials: ConnectionCredentials?
}

// MARK: - Folder Import Strategy

enum FolderImportStrategy: String, CaseIterable {
    case mergeByName
    case recreate
    case flatten

    var displayName: String {
        switch self {
        case .mergeByName: return String(localized: "Merge by Name", comment: "Folder import strategy")
        case .recreate: return String(localized: "Recreate All", comment: "Folder import strategy")
        case .flatten: return String(localized: "Ignore Folders", comment: "Folder import strategy")
        }
    }

    var description: String {
        switch self {
        case .mergeByName: return String(localized: "Match existing folders by name, create new ones if needed", comment: "Folder import strategy description")
        case .recreate: return String(localized: "Always create new folders", comment: "Folder import strategy description")
        case .flatten: return String(localized: "Import all connections without folders", comment: "Folder import strategy description")
        }
    }
}
