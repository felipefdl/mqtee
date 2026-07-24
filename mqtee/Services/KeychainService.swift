//
//  KeychainService.swift
//  mqtee
//

import Foundation
import Security

struct ConnectionCredentials: Codable {
    var username: String?
    var password: String?
    var clientCertificate: Data?
    var clientKey: Data?
    var caCertificate: Data?
}

enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case notFound
    case encodingFailed
    case decodingFailed
}

final class KeychainService {
    static let shared = KeychainService()
    
    private let service = "\(StorageEnvironment.keyPrefix)com.mqtee.connections"
    
    private init() {}
    
    // MARK: - Credentials
    
    func saveCredentials(_ credentials: ConnectionCredentials, for connectionId: UUID) throws {
        let account = connectionId.uuidString
        
        guard let data = try? JSONEncoder().encode(credentials) else {
            throw KeychainError.encodingFailed
        }
        
        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        var status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        
        if status == errSecItemNotFound {
            // Item doesn't exist, add it
            var addQuery = updateQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            addQuery[kSecAttrSynchronizable as String] = kCFBooleanTrue as Any
            
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }
    
    func loadCredentials(for connectionId: UUID) throws -> ConnectionCredentials {
        let account = connectionId.uuidString
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.unknown(status)
        }
        
        guard let credentials = try? JSONDecoder().decode(ConnectionCredentials.self, from: data) else {
            throw KeychainError.decodingFailed
        }
        
        return credentials
    }
    
    func deleteCredentials(for connectionId: UUID) throws {
        let account = connectionId.uuidString
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]

        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    func deleteAllCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}
