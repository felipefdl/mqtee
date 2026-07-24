//
//  ConnectionManagerView+Lifecycle.swift
//  mqtee
//

import SwiftUI

extension ConnectionManagerView {
    func handleBack() {
        if activeSession?.isConnected == true {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showDisconnectConfirmation = true
            }
        } else {
            if let id = activeSession?.connection.id {
                ActiveConnectionTracker.shared.release(id)
            }
            activeSession?.cleanup()
            activeSession = nil
        }
    }

    func folderForSession(_ session: SessionStore) -> ConnectionFolder? {
        guard let folderId = session.connection.folderId else { return nil }
        return store.folders.first { $0.id == folderId }
    }

    func connectTo(_ connection: Connection) {
        guard activeSession == nil else { return }

        if Self.isScreenshotMode {
            selectedConnectionId = connection.id
            activeSession = MockData.makeSessionStore()
            return
        }

        guard ActiveConnectionTracker.shared.claim(connection.id) else { return }

        var updated = connection
        updated.lastConnectedAt = Date()
        selectedConnectionId = updated.id

        // Show overlay instantly before any heavy work
        connectingToConnection = updated

        // Defer heavy work so the overlay renders first
        Task { @MainActor in
            store.updateConnection(updated)

            let session = SessionStore(connection: updated)
            activeSession = session

            session.connect()

            let connectionId = updated.id
            let persistSession = updated.persistSession
            Task.detached {
                let sessionData = persistSession ? SessionPersistenceService.loadSessionData(for: connectionId) : nil
                let publishTabsData = SessionPersistenceService.loadPublishTabsData(for: connectionId)

                await MainActor.run {
                    session.applyPersistedData(session: sessionData, publishTabs: publishTabsData)
                }
            }

            // Wait until connected, terminally failed, or cancelled (timeout 30s)
            let deadline = ContinuousClock.now + .seconds(30)
            while !session.isConnected {
                // User tapped Cancel
                guard connectingToConnection != nil else { return }
                // Timed out
                guard ContinuousClock.now < deadline else { break }
                // Failed and not going to retry
                if session.connectionError != nil && !session.isReconnecting { break }
                try? await Task.sleep(for: .milliseconds(100))
            }

            connectingToConnection = nil

            // On failure or timeout: tear down and go back
            if !session.isConnected {
                ActiveConnectionTracker.shared.release(updated.id)
                session.cleanup()
                activeSession = nil
            }
        }
    }

    func loadScreenshotData() async {
        MockData.populateLogStore()

        let args = ProcessInfo.processInfo.arguments

        // Auto-connect to mock session if --screenshot-session is present
        if args.contains("--screenshot-session") {
            let session = MockData.makeSessionStore()
            activeSession = session

            // Auto-show publish panel
            if args.contains("--screenshot-publish") {
                session.showPublishPopover = true
            }

            // Auto-show log panel
            if args.contains("--screenshot-log") {
                session.showLogSheet = true
            }
        }

        // Auto-open connection editor (for security screenshot)
        if args.contains("--screenshot-editor") {
            try? await Task.sleep(for: .seconds(0.5))
            connectionToEdit = store.connections.first { $0.useTLS }
        }
    }

    func importConnections() {
        showingFilePicker = true
    }

    func exportConnections() {
        exportSpecificConnections = nil
        showingExportSheet = true
    }

    func performReset() {
        selectedConnectionId = nil
        DataResetService.resetAllData(activeSession: &activeSession, connectionStore: store)
    }

    #if DEBUG
    func resetAndAddSampleBrokers() {
        selectedConnectionId = nil
        DataResetService.resetAllData(activeSession: &activeSession, connectionStore: store)

        let homeFolder = ConnectionFolder(name: "Home", color: .green)
        let cloudFolder = ConnectionFolder(name: "Public", color: .blue)
        let testFolder = ConnectionFolder(name: "Testing", color: .purple)
        store.addFolder(homeFolder)
        store.addFolder(cloudFolder)
        store.addFolder(testFolder)

        let samples: [Connection] = [
            Connection(name: "Home Assistant", host: "localhost", port: 1883, folderId: homeFolder.id, mqttVersion: .v311),
            Connection(name: "Zigbee2MQTT", host: "192.168.1.2", port: 1883, folderId: homeFolder.id, mqttVersion: .v311, username: "lima"),
            Connection(name: "Public Broker", host: "broker.emqx.io", port: 1883, folderId: cloudFolder.id, mqttVersion: .v5),
            Connection(name: "Public Broker (TLS)", host: "broker.emqx.io", port: 8883, folderId: cloudFolder.id, mqttVersion: .v5, useTLS: true),
            Connection(name: "Test Broker", host: "test.mosquitto.org", port: 1883, folderId: testFolder.id),
            Connection(name: "Test Broker (TLS)", host: "test.mosquitto.org", port: 8886, folderId: testFolder.id, useTLS: true),
        ]
        for connection in samples {
            store.addConnection(connection)
        }
    }
    #endif

    func exportSingleConnection(_ connection: Connection) {
        exportSpecificConnections = [connection]
        showingExportSheet = true
    }
}
