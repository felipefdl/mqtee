import Testing
import Foundation
@testable import MQTee

@Suite("DataResetService")
@MainActor
struct DataResetServiceTests {

    @Test("resetAllData clears settings keys")
    func resetClearsSettings() {
        // Arrange: write a settings key that should be cleared
        UserDefaults.standard.set("5.0", forKey: "defaultMQTTVersion")

        let store = ConnectionStore.mock(connections: [
            Connection(name: "Test", host: "broker.local"),
        ])
        var session: SessionStore? = nil

        // Act
        DataResetService.resetAllData(activeSession: &session, connectionStore: store)

        // Assert: settings key cleared
        #expect(UserDefaults.standard.object(forKey: "defaultMQTTVersion") == nil)
    }
}
