import Testing
import Foundation
@testable import MQTee

@Suite("ConnectionStore", .serialized)
@MainActor
struct ConnectionStoreTests {

    // MARK: - Connection CRUD

    @Test("addConnection appends to connections")
    func addConnectionAppends() {
        let store = ConnectionStore()
        let conn = Connection(name: "Test", host: "broker.local")
        store.addConnection(conn)

        #expect(store.connections.contains { $0.id == conn.id })
    }

    @Test("updateConnection modifies existing connection")
    func updateConnectionModifies() {
        let store = ConnectionStore()
        var conn = Connection(name: "Test", host: "broker.local")
        store.addConnection(conn)

        conn.name = "Updated"
        store.updateConnection(conn)

        #expect(store.connections.first { $0.id == conn.id }?.name == "Updated")
    }

    @Test("deleteConnection removes from connections")
    func deleteConnectionRemoves() {
        let store = ConnectionStore()
        let conn = Connection(name: "Test", host: "broker.local")
        store.addConnection(conn)
        store.deleteConnection(conn)

        #expect(!store.connections.contains { $0.id == conn.id })
    }

    // MARK: - Folder CRUD

    @Test("addFolder appends to folders")
    func addFolderAppends() {
        let store = ConnectionStore()
        let folder = ConnectionFolder(name: "My Folder")
        store.addFolder(folder)

        #expect(store.folders.contains { $0.id == folder.id })
    }

    @Test("updateFolder modifies existing folder")
    func updateFolderModifies() {
        let store = ConnectionStore()
        var folder = ConnectionFolder(name: "Original")
        store.addFolder(folder)

        folder.name = "Renamed"
        store.updateFolder(folder)

        #expect(store.folders.first { $0.id == folder.id }?.name == "Renamed")
    }

    @Test("deleteFolder moves connections to unfoldered")
    func deleteFolderMovesConnections() {
        let store = ConnectionStore()
        let folder = ConnectionFolder(name: "Folder")
        store.addFolder(folder)

        let conn = Connection(name: "Test", host: "broker.local", folderId: folder.id)
        store.addConnection(conn)

        store.deleteFolder(folder)

        #expect(!store.folders.contains { $0.id == folder.id })
        #expect(store.connections.first { $0.id == conn.id }?.folderId == nil)
    }

    // MARK: - Folder queries

    @Test("connections(in:) filters by folder")
    func connectionsInFolder() {
        let store = ConnectionStore()
        let folder = ConnectionFolder(name: "Folder")
        store.addFolder(folder)

        let conn1 = Connection(name: "In Folder", host: "a.local", folderId: folder.id)
        let conn2 = Connection(name: "Not In Folder", host: "b.local")
        store.addConnection(conn1)
        store.addConnection(conn2)

        let inFolder = store.connections(in: folder)
        #expect(inFolder.contains { $0.id == conn1.id })
        #expect(!inFolder.contains { $0.id == conn2.id })
    }

    @Test("unfolderedConnections returns connections without folder")
    func unfolderedConnections() {
        let store = ConnectionStore()
        let folder = ConnectionFolder(name: "F")
        store.addFolder(folder)

        let conn1 = Connection(name: "Foldered", host: "a.local", folderId: folder.id)
        let conn2 = Connection(name: "Unfoldered", host: "b.local")
        store.addConnection(conn1)
        store.addConnection(conn2)

        let unfoldered = store.unfolderedConnections
        #expect(unfoldered.contains { $0.id == conn2.id })
        #expect(!unfoldered.contains { $0.id == conn1.id })
    }

    @Test("sortedFolders returns alphabetically sorted")
    func sortedFolders() {
        let store = ConnectionStore()
        let z = ConnectionFolder(name: "Zebra")
        let a = ConnectionFolder(name: "Alpha")
        let m = ConnectionFolder(name: "middle")
        store.addFolder(z)
        store.addFolder(a)
        store.addFolder(m)

        let sorted = store.sortedFolders
        // Verify relative ordering of our three added folders
        let zIdx = sorted.firstIndex { $0.id == z.id }!
        let aIdx = sorted.firstIndex { $0.id == a.id }!
        let mIdx = sorted.firstIndex { $0.id == m.id }!
        #expect(aIdx < mIdx)
        #expect(mIdx < zIdx)
    }

    // MARK: - Move connection

    @Test("moveConnection changes folder assignment")
    func moveConnectionChangesFolder() {
        let store = ConnectionStore()
        let folder = ConnectionFolder(name: "Target")
        store.addFolder(folder)

        let conn = Connection(name: "Test", host: "broker.local")
        store.addConnection(conn)

        store.moveConnection(conn, to: folder)

        #expect(store.connections.first { $0.id == conn.id }?.folderId == folder.id)
    }

    @Test("moveConnection to nil removes from folder")
    func moveConnectionToNil() {
        let store = ConnectionStore()
        let folder = ConnectionFolder(name: "Folder")
        store.addFolder(folder)

        let conn = Connection(name: "Test", host: "broker.local", folderId: folder.id)
        store.addConnection(conn)

        store.moveConnection(conn, to: nil)

        #expect(store.connections.first { $0.id == conn.id }?.folderId == nil)
    }

    // MARK: - Duplication

    @Test("duplicateConnection creates unique name")
    func duplicateConnectionUniqueName() {
        let store = ConnectionStore()
        // Remove any existing "Broker" connections to avoid interference
        let uniqueName = "TestBroker-\(UUID().uuidString.prefix(8))"
        let conn = Connection(name: uniqueName, host: "broker.local")
        store.addConnection(conn)

        let dup = store.duplicateConnection(conn)

        #expect(dup.name == "\(uniqueName) (2)")
        #expect(dup.id != conn.id)
        #expect(dup.host == conn.host)
        #expect(dup.port == conn.port)
    }

    @Test("duplicateConnection increments number if name exists")
    func duplicateConnectionIncrementsNumber() {
        let store = ConnectionStore()
        let uniqueName = "TestBroker-\(UUID().uuidString.prefix(8))"
        let conn = Connection(name: uniqueName, host: "broker.local")
        store.addConnection(conn)

        let dup1 = store.duplicateConnection(conn)
        #expect(dup1.name == "\(uniqueName) (2)")

        let dup2 = store.duplicateConnection(conn)
        #expect(dup2.name == "\(uniqueName) (3)")
    }

    @Test("duplicateConnection generates new clientId")
    func duplicateConnectionNewClientId() {
        let store = ConnectionStore()
        let conn = Connection(name: "Test", host: "broker.local", clientId: "my-client")
        store.addConnection(conn)

        let dup = store.duplicateConnection(conn)

        #expect(dup.clientId != conn.clientId)
        #expect(dup.clientId.hasPrefix("mqtee-"))
    }

    @Test("duplicateConnection preserves MQTT settings")
    func duplicateConnectionPreservesSettings() {
        let store = ConnectionStore()
        let conn = Connection(
            name: "Test", host: "broker.local", port: 8883,
            mqttVersion: .v5, cleanSession: false, keepAlive: 120,
            sessionExpiry: 3600, useTLS: true, allowInsecureTLS: true
        )
        store.addConnection(conn)

        let dup = store.duplicateConnection(conn)

        #expect(dup.mqttVersion == .v5)
        #expect(dup.cleanSession == false)
        #expect(dup.keepAlive == 120)
        #expect(dup.sessionExpiry == 3600)
        #expect(dup.useTLS == true)
        #expect(dup.allowInsecureTLS == true)
        #expect(dup.port == 8883)
    }
}
