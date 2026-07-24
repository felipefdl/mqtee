import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Device Client ID

extension MQTTService {
    static func deviceClientId(for connectionId: UUID) -> String {
        let key = "\(StorageEnvironment.keyPrefix)deviceClientId.\(connectionId.uuidString)"
        if let stored = UserDefaults.standard.string(forKey: key) {
            return stored
        }
        // No local entry = synced from another device -> generate fresh random ID
        let generated = "mqtee-\(UUID().uuidString.prefix(8))"
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }

    static func setDeviceClientId(_ clientId: String, for connectionId: UUID) {
        UserDefaults.standard.set(clientId, forKey: "\(StorageEnvironment.keyPrefix)deviceClientId.\(connectionId.uuidString)")
    }

    static func removeDeviceClientId(for connectionId: UUID) {
        UserDefaults.standard.removeObject(forKey: "\(StorageEnvironment.keyPrefix)deviceClientId.\(connectionId.uuidString)")
    }

    static var currentDeviceId: String {
        let key = "\(StorageEnvironment.keyPrefix)mqteeDeviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    static var currentDeviceName: String {
        #if os(macOS)
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #else
        UIDevice.current.name
        #endif
    }
}
