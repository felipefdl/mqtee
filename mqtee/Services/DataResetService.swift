//
//  DataResetService.swift
//  mqtee
//

import Foundation
import os

private let logger = Logger(subsystem: "app.mqtee", category: "DataReset")

@MainActor
enum DataResetService {

    /// Performs a full reset of all user-created data.
    static func resetAllData(
        activeSession: inout SessionStore?,
        connectionStore: ConnectionStore
    ) {
        logger.warning("Performing full data reset")

        // 1. Disconnect active session
        if let session = activeSession {
            ActiveConnectionTracker.shared.release(session.connection.id)
            session.cleanup()
            activeSession = nil
        }

        // 2. Clear in-memory state
        LogStore.shared.clear()
        FaviconService.shared.deleteAllIcons()

        // 3. Delete all Keychain credentials
        try? KeychainService.shared.deleteAllCredentials()

        // 4. Delete all session and icon files from disk
        SessionPersistenceService.shared.deleteAllSessions()

        // 5. Remove UserDefaults keys (settings + device IDs)
        let defaults = UserDefaults.standard
        let prefix = StorageEnvironment.keyPrefix

        // Remove per-connection device client IDs
        for connection in connectionStore.connections {
            defaults.removeObject(forKey: "\(prefix)deviceClientId.\(connection.id.uuidString)")
        }

        // Remove device ID
        defaults.removeObject(forKey: "\(prefix)mqteeDeviceId")

        // Remove app settings
        let settingsKeys = [
            "defaultMQTTVersion",
            "defaultKeepAlive",
            "maxMessagesInMemory",
            "maxPersistedMessages",
            "batchLogThreshold",
            "autoReconnect",
            "reconnectInterval",
        ]
        for key in settingsKeys {
            defaults.removeObject(forKey: key)
        }

        // 6. Clear iCloud + in-memory connections and folders
        connectionStore.resetAllData()

        logger.warning("Full data reset completed")
    }
}
