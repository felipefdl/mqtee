//
//  ConnectionEditorView+Save.swift
//  mqtee
//

import SwiftUI

extension ConnectionEditorView {
    func saveConnection() {
        let portNumber = Int(port) ?? 1883
        let keepAliveSeconds = Int(keepAlive) ?? 60
        let sessionExpirySeconds = Int(sessionExpiry)
        let connectionId = existingConnection?.id ?? UUID()

        let lastWillConfig = LastWillSettings(
            enabled: lastWillEnabled,
            topic: lastWillTopic,
            message: lastWillMessage,
            qos: lastWillQoS,
            retain: lastWillRetain
        )

        let connection = Connection(
            id: connectionId,
            name: name,
            host: host,
            port: portNumber,
            folderId: selectedFolderId,
            mqttVersion: mqttVersion,
            clientId: clientId,
            cleanSession: cleanSession,
            keepAlive: keepAliveSeconds,
            sessionExpiry: sessionExpirySeconds,
            username: username.isEmpty ? nil : username,
            useTLS: useTLS,
            useClientCertificate: useClientCertificate,
            allowInsecureTLS: allowInsecureTLS,
            lastWill: lastWillConfig,
            persistSession: persistSession,
            autoSubscribe: autoSubscribe
        )

        // Store the user's chosen client ID as this device's ID
        let effectiveClientId = clientId.isEmpty ? "mqtee-\(UUID().uuidString.prefix(8))" : clientId
        MQTTService.setDeviceClientId(effectiveClientId, for: connectionId)

        // Publish to iCloud for cross-device conflict detection
        store.publishDeviceClientId(effectiveClientId, for: connectionId)

        // Save credentials to Keychain
        let credentials = ConnectionCredentials(
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            clientCertificate: clientCertificateData,
            clientKey: clientKeyData,
            caCertificate: caCertificateData
        )
        try? keychain.saveCredentials(credentials, for: connectionId)

        let hostChanged = existingConnection?.host != host
        let isNew = existingConnection == nil

        if !isNew {
            if let index = store.connections.firstIndex(where: { $0.id == connection.id }) {
                store.connections[index] = connection
            }
        } else {
            store.addConnection(connection)
        }

        if hostChanged {
            FaviconService.shared.deleteIcon(for: connectionId)
        }

        let hasNoIcon = FaviconService.shared.loadedIcons[connectionId] == nil
        if isNew || hostChanged || hasNoIcon {
            Task {
                await FaviconService.shared.fetchFavicon(for: connectionId, host: host)
            }
        }
    }

    func updatePortForTLS() {
        if useTLS && port == "1883" {
            port = "8883"
        } else if !useTLS && port == "8883" {
            port = "1883"
        }
    }
}
