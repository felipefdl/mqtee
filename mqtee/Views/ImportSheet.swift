//
//  ImportSheet.swift
//  mqtee
//

import SwiftUI

struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: ConnectionStore
    let importResult: ImportExportService.ImportResult

    @State private var importCredentials = true
    @State private var folderStrategy: FolderImportStrategy = .mergeByName
    @State private var appeared = false

    private var document: ExportDocument { importResult.document }
    private var hasCredentials: Bool { document.connections.contains { $0.credentials != nil } }
    private var hasFolders: Bool { !document.folders.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            Divider()

            footer
        }
        #if os(macOS)
        .frame(width: 440, height: 480)
        #endif
        .onAppear {
            withAnimation(BrandTheme.springGentle) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Import Connections")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            // File info
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                Text(importResult.fileURL.lastPathComponent)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Summary
            let connCount = document.connections.count
            let folderCount = document.folders.count
            if folderCount > 0 {
                Text("\(connCount) connections, \(folderCount) folders")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(connCount) connections")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if document.version > ExportDocument.currentVersion {
                Label(
                    "This file was created by a newer version of MQTee. Some data may not import correctly.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout)
                .foregroundStyle(.orange)
            }

            Divider()

            // Connection preview list
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(document.connections.enumerated()), id: \.element.connection.id) { index, exported in
                        HStack(spacing: 8) {
                            Image(systemName: "server.rack")
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exported.connection.name)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(exported.connection.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if exported.credentials != nil {
                                Image(systemName: "key.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .staggeredEntrance(appeared: appeared, delay: Double(index) * 0.03)
                    }
                }
            }
            .frame(maxHeight: 180)

            Divider()

            // Options
            if hasCredentials {
                Toggle("Import credentials (passwords, certificates)", isOn: $importCredentials)
            }

            if hasFolders {
                Picker("Folders:", selection: $folderStrategy) {
                    ForEach(FolderImportStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(.menu)

                Text(folderStrategy.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            let count = document.connections.count
            Button("Import \(count) connections") {
                _ = ImportExportService.performImport(
                    document: document,
                    store: store,
                    importCredentials: hasCredentials && importCredentials,
                    folderStrategy: hasFolders ? folderStrategy : .flatten
                )
                dismiss()
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
