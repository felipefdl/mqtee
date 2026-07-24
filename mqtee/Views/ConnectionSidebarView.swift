//
//  ConnectionSidebarView.swift
//  mqtee
//

import SwiftUI

struct ConnectionSidebarView: View {
    @Bindable var store: ConnectionStore
    @Binding var selectedConnectionId: Connection.ID?
    var onConnect: (Connection) -> Void
    var onEdit: (Connection) -> Void
    var onExportConnection: (Connection) -> Void
    var onNewConnection: () -> Void
    var onImport: () -> Void
    var onExport: () -> Void
    var onShowSettings: () -> Void = {}

    private var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    @State private var showingFolderManager = false

    private var addMenu: some View {
        Menu {
            Button(action: onNewConnection) {
                Label("New Connection", systemImage: "plus")
            }
            Button(action: onImport) {
                Label("Import", systemImage: "square.and.arrow.down")
            }

            Divider()

            Button {
                showingFolderManager = true
            } label: {
                Label("Folders", systemImage: "folder")
            }
        } label: {
            Label("Add", systemImage: "plus")
        } primaryAction: {
            onNewConnection()
        }
    }

    var body: some View {
        List(selection: $selectedConnectionId) {
            if !store.connections.isEmpty {
                // Connections not in any folder
                if isPhone {
                    ForEach(store.unfolderedConnections) { connection in
                        connectionRow(connection, folderColor: .gray)
                    }
                } else {
                    Section("Connections") {
                        ForEach(store.unfolderedConnections) { connection in
                            connectionRow(connection, folderColor: .gray)
                        }
                    }
                }

                // Folder sections
                ForEach(store.sortedFolders) { folder in
                    Section {
                        ForEach(store.connections(in: folder)) { connection in
                            connectionRow(connection, folderColor: folder.color.color)
                        }
                    } header: {
                        folderSectionHeader(folder)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if store.connections.isEmpty {
                if store.isSyncing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Syncing with iCloud...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isPhone {
                    VStack(spacing: 32) {
                        Spacer()

                        VStack(spacing: 20) {
                            Image("MQTeeLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                                .foregroundStyle(.primary)

                            VStack(spacing: 6) {
                                HStack(spacing: 0) {
                                    Text("Welcome to ")
                                        .font(.largeTitle)
                                        .fontWeight(.semibold)
                                    AppNameText(size: .largeTitle)
                                }

                                Text("Your MQTT companion")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 12) {
                            Button(action: onNewConnection) {
                                Label("New Connection", systemImage: "plus.circle")
                            }
                            .buttonStyle(.glass)

                            Button(action: onImport) {
                                Label("Import", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.glass)
                        }

                        Spacer()

                        Text(Bundle.main.appVersion)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("No Connections", systemImage: "server.rack")
                            .foregroundStyle(.secondary)
                    } description: {
                        Text("Add a connection to get started")
                    } actions: {
                        Button(action: onNewConnection) {
                            Label("New Connection", systemImage: "plus.circle")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
            }
        }
        .navigationTitle(store.connections.isEmpty && isPhone ? "" : "Connections")
        .toolbar {
            #if !os(macOS)
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onShowSettings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            #endif
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: onNewConnection) {
                        Label("New Connection", systemImage: "plus")
                    }
                    Button {
                        showingFolderManager = true
                    } label: {
                        Label("Folders", systemImage: "folder")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                } primaryAction: {
                    onNewConnection()
                }
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                if !isPhone || !store.connections.isEmpty {
                    addMenu
                }
            }
            #endif
        }
        .sheet(isPresented: $showingFolderManager) {
            FolderManagerSheet(store: store)
        }
    }

    // MARK: - Connection Row

    @ViewBuilder
    private func connectionRow(_ connection: Connection, folderColor: Color) -> some View {
        ConnectionRowView(connection: connection, folderColor: folderColor)
            .tag(connection.id)
            .contextMenu {
                connectionContextMenu(for: connection)
            }
    }

    // MARK: - Folder Section Header

    private func folderSectionHeader(_ folder: ConnectionFolder) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(folder.color.color)
                .frame(width: 8, height: 8)
            Text(folder.name)
        }
        .contextMenu {
            Menu("Color") {
                ForEach(FolderColor.allCases, id: \.self) { color in
                    Button {
                        var updated = folder
                        updated.color = color
                        store.updateFolder(updated)
                    } label: {
                        HStack {
                            Image(systemName: folder.color == color ? "checkmark.circle.fill" : "circle.fill")
                            Text(color.localizedName)
                        }
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                store.deleteFolder(folder)
            } label: {
                Label("Delete Folder", systemImage: "trash")
            }
        }
    }

    // MARK: - Connection Context Menu

    @ViewBuilder
    private func connectionContextMenu(for connection: Connection) -> some View {
        Button {
            onConnect(connection)
        } label: {
            Label("Connect", systemImage: "bolt.fill")
        }
        .disabled(ActiveConnectionTracker.shared.isActive(connection.id))

        Divider()

        Button {
            onEdit(connection)
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            let duplicate = store.duplicateConnection(connection)
            selectedConnectionId = duplicate.id
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }

        Menu("Move to Folder") {
            Button {
                store.moveConnection(connection, to: nil)
            } label: {
                HStack {
                    if connection.folderId == nil {
                        Image(systemName: "checkmark")
                    }
                    Text("None")
                }
            }

            Divider()

            ForEach(store.sortedFolders) { folder in
                Button {
                    store.moveConnection(connection, to: folder)
                } label: {
                    HStack {
                        if connection.folderId == folder.id {
                            Image(systemName: "checkmark")
                        }
                        Circle()
                            .fill(folder.color.color)
                            .frame(width: 8, height: 8)
                        Text(folder.name)
                    }
                }
            }
        }

        Button {
            onExportConnection(connection)
        } label: {
            Label("Export...", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            if selectedConnectionId == connection.id {
                selectedConnectionId = nil
            }
            store.deleteConnection(connection)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

}
