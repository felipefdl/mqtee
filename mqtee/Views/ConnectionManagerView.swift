//
//  ConnectionManagerView.swift
//  mqtee
//

import SwiftUI
import UniformTypeIdentifiers

struct ConnectionManagerView: View {
    @State var store = Self.makeStore()
    #if DEBUG
    @State var selectedConnectionId: Connection.ID? =
        (isScreenshotMode && !isScreenshotWelcome) ? MockData.connections.first?.id : nil
    #else
    @State var selectedConnectionId: Connection.ID?
    #endif

    private static func makeStore() -> ConnectionStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
            return MockData.makeConnectionStore()
        }
        #endif
        return ConnectionStore()
    }

    private var selectedConnection: Connection? {
        guard let id = selectedConnectionId else { return nil }
        return store.connections.first { $0.id == id }
    }

    @State var showingNewConnection = false
    @State var connectionToEdit: Connection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State var activeSession: SessionStore?
    @State var showDisconnectConfirmation = false
    @State var showingExportSheet = false
    @State var showingFilePicker = false
    @State private var importResult: ImportExportService.ImportResult?
    @State var exportSpecificConnections: [Connection]?
    @State private var importError: String?
    @State var showingSettings = false
    #if os(macOS)
    @State var showingResetSheet = false
    #endif

    @State var connectingToConnection: Connection?
    @Environment(\.scenePhase) private var scenePhase

    #if DEBUG
    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
            || ProcessInfo.processInfo.arguments.contains("--screenshot-welcome")
    }

    private static var isScreenshotWelcome: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-welcome")
    }
    #else
    static let isScreenshotMode = false
    #endif

    var body: some View {
        rootContent
            .task {
                if Self.isScreenshotMode {
                    await loadScreenshotData()
                    return
                }
                FaviconService.shared.loadAllIcons(for: store.connections.map(\.id))
            }
            .onChange(of: store.connections) {
                FaviconService.shared.loadAllIcons(for: store.connections.map(\.id))
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    store.synchronize()
                }
            }
            .sheet(isPresented: $showingNewConnection) {
                ConnectionEditorView(store: store)
            }
            #if !os(macOS)
            .sheet(isPresented: $showingSettings) {
                settingsSheet
            }
            #endif
            .sheet(item: $connectionToEdit) { connection in
                ConnectionEditorView(store: store, existingConnection: connection)
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheet(store: store, specificConnections: exportSpecificConnections)
            }
            .sheet(item: $importResult) { result in
                ImportSheet(store: store, importResult: result)
            }
            #if os(macOS)
            .sheet(isPresented: $showingResetSheet) {
                ResetDataSheet(onConfirm: performReset)
            }
            #endif
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.mqteeExport, .json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    if let parsed = ImportExportService.parseImportFile(at: url) {
                        importResult = parsed
                    } else {
                        importError = String(localized: "The selected file is not a valid MQTee export.", comment: "Import error")
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .alert("Import Error", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            #if os(macOS)
            .focusedSceneValue(\.importConnections, importConnections)
            .focusedSceneValue(\.exportConnections, exportConnections)
            .focusedSceneValue(\.resetAllData) { showingResetSheet = true }
            #if DEBUG
            .focusedSceneValue(\.resetAndAddSampleBrokers) {
                resetAndAddSampleBrokers()
            }
            #endif
            #endif
    }

    private var rootContent: some View {
        Group {
            if let session = activeSession {
                SessionView(session: session, folder: folderForSession(session), onBack: handleBack)
                    #if os(macOS)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button(action: handleBack) {
                                Label("Disconnect", systemImage: "eject")
                            }
                            .popover(isPresented: $showDisconnectConfirmation, arrowEdge: .bottom) {
                                DisconnectPopover(connectionName: session.connection.name) {
                                    let id = session.connection.id
                                    ActiveConnectionTracker.shared.release(id)
                                    session.cleanup()
                                    activeSession = nil
                                }
                            }
                        }
                    }
                    #else
                    .confirmationDialog(
                        "Disconnect from \(session.connection.name)?",
                        isPresented: $showDisconnectConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Disconnect", role: .destructive) {
                            let id = session.connection.id
                            ActiveConnectionTracker.shared.release(id)
                            session.cleanup()
                            activeSession = nil
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                    #endif
            } else {
                connectionManagerContent
            }
        }
        .sheet(item: $connectingToConnection) { connection in
            ConnectingSheet(
                connectionName: connection.name,
                connectionId: connection.id,
                onCancel: {
                    ActiveConnectionTracker.shared.release(connection.id)
                    activeSession?.cleanup()
                    activeSession = nil
                    connectingToConnection = nil
                }
            )
            .interactiveDismissDisabled()
        }
        .navigationTitle(activeSession?.connection.name ?? "MQTee")
        #if os(macOS)
        .frame(minWidth: 1250)
        .focusedSceneValue(\.selectedConnection, activeSession == nil ? selectedConnection : nil)
        .focusedSceneValue(\.activeSession, activeSession)
        .focusedSceneValue(\.connectToConnection, connectTo)
        .focusedSceneValue(\.editConnection) { connection in
            connectionToEdit = connection
        }
        .focusedSceneValue(\.deleteConnection) { [self] connection in
            if selectedConnectionId == connection.id {
                selectedConnectionId = nil
            }
            store.deleteConnection(connection)
        }
        .focusedSceneValue(\.duplicateConnection) { connection in
            let duplicate = store.duplicateConnection(connection)
            selectedConnectionId = duplicate.id
        }
        #endif
    }

    private var connectionManagerContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Connection list
            ConnectionSidebarView(
                store: store,
                selectedConnectionId: $selectedConnectionId,
                onConnect: connectTo,
                onEdit: { connectionToEdit = $0 },
                onExportConnection: exportSingleConnection,
                onNewConnection: { showingNewConnection = true },
                onImport: importConnections,
                onExport: exportConnections,
                onShowSettings: { showingSettings = true }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        } detail: {
            // Detail - Welcome or connection detail
            if let connection = selectedConnection {
                ConnectionDetailView(
                    connection: connection,
                    onConnect: connectTo,
                    onEdit: { connectionToEdit = $0 }
                )
            } else {
                WelcomeView(
                    onNewConnection: { showingNewConnection = true },
                    onImport: importConnections,
                    onExport: exportConnections,
                    exportDisabled: store.connections.isEmpty
                )
            }
        }
        #if os(macOS)
        .onKeyPress(.escape) {
            if selectedConnectionId != nil {
                selectedConnectionId = nil
                return .handled
            }
            return .ignored
        }
        #endif
    }

    #if !os(macOS)
    private var settingsSheet: some View {
        #if DEBUG
        SettingsSheet(onResetAllData: performReset, onLoadSampleData: resetAndAddSampleBrokers)
        #else
        SettingsSheet(onResetAllData: performReset)
        #endif
    }
    #endif
}

#Preview {
    ConnectionManagerView()
        .frame(width: 700, height: 500)
}
