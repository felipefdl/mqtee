import Testing
@testable import MQTee

@Suite("Reconnect backoff")
@MainActor
struct ReconnectBackoffTests {

    @Test("doubles from the base interval until the cap")
    func doublesUntilCap() {
        let delays = (1...6).map { SessionStore.reconnectDelay(attempt: $0, baseInterval: 5) }
        #expect(delays == [5, 10, 20, 40, 60, 60])
    }

    @Test("stays capped through long outages instead of overflowing", arguments: [62, 64, 1_000, Int.max])
    func longOutageStaysCapped(attempt: Int) {
        #expect(SessionStore.reconnectDelay(attempt: attempt, baseInterval: 5) == 60)
        #expect(SessionStore.reconnectDelay(attempt: attempt, baseInterval: 60) == 60)
    }
}
