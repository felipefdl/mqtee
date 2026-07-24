import Testing
import Foundation
@testable import MQTee

@Suite("SubscriptionColor")
struct SubscriptionColorTests {

    @Test("next after empty returns .blue (first in allCases)")
    func nextAfterEmptyReturnsBlue() {
        let result = SubscriptionColor.next(after: [])
        #expect(result == .blue)
    }

    @Test("next after [.blue] returns .green (second)")
    func nextAfterBlueReturnsGreen() {
        let result = SubscriptionColor.next(after: [.blue])
        #expect(result == .green)
    }

    @Test("next skips used colors")
    func nextSkipsUsedColors() {
        let result = SubscriptionColor.next(after: [.blue, .green])
        #expect(result == .orange)
    }

    @Test("next after all cases returns a valid case")
    func nextAfterAllCasesReturnsValidCase() {
        let allColors = SubscriptionColor.allCases
        let result = SubscriptionColor.next(after: Array(allColors))
        #expect(SubscriptionColor.allCases.contains(result))
    }
}
