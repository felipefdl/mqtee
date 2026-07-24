//
//  ExportSheet.swift
//  mqtee
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: ConnectionStore
    var specificConnections: [Connection]?

    @State private var includeCredentials = false
    @State private var showingFileExporter = false
    @State private var exportDocument: MQTeeExportFile?

    private var connectionsToExport: [Connection] {
        specificConnections ?? store.connections
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            Divider()

            footer
        }
        #if os(macOS)
        .frame(width: 400)
        #endif
        .fileExporter(
            isPresented: $showingFileExporter,
            document: exportDocument,
            contentType: .mqteeExport,
            defaultFilename: "connections.mqtee"
        ) { result in
            if case .success = result {
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Export Connections")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            let count = connectionsToExport.count
            Text("\(count) connections will be exported.")
                .font(.body)

            Toggle("Include credentials (passwords, certificates)", isOn: $includeCredentials.animation(BrandTheme.springGentle))

            if includeCredentials {
                Label(
                    "Credentials will be stored in plain text in the exported file. Share this file carefully.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout)
                .foregroundStyle(.orange)
                .transition(.move(edge: .top).combined(with: .opacity))
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

            Button("Export...") {
                guard let data = ImportExportService.prepareExportData(
                    connectionsToExport,
                    folders: store.folders,
                    includeCredentials: includeCredentials
                ) else { return }
                exportDocument = MQTeeExportFile(data: data)
                showingFileExporter = true
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
