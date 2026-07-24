import Testing
import Foundation
@testable import MQTee

@Suite("MessageFilterState")
struct MessageFilterStateTests {

    // MARK: - Helpers

    private func makeMessage(
        topic: String = "test/topic",
        payload: String = "hello",
        qos: QoSLevel = .atMostOnce,
        retained: Bool = false,
        sentByMe: Bool = false,
        timestamp: Date = Date()
    ) -> MQTTMessage {
        MQTTMessage(
            topic: topic,
            payloadString: payload,
            qos: qos,
            retained: retained,
            timestamp: timestamp,
            sentByMe: sentByMe
        )
    }

    private var sampleMessages: [MQTTMessage] {
        [
            makeMessage(topic: "sensors/temp", payload: "22.5", qos: .atMostOnce, retained: false, sentByMe: false),
            makeMessage(topic: "sensors/humidity", payload: "65", qos: .atLeastOnce, retained: true, sentByMe: false),
            makeMessage(topic: "control/light", payload: "{\"state\":\"on\"}", qos: .exactlyOnce, retained: false, sentByMe: true),
            makeMessage(topic: "sensors/temp", payload: "23.1", qos: .atMostOnce, retained: false, sentByMe: false),
        ]
    }

    // MARK: - Default State

    @Test("default state is not active")
    func defaultStateNotActive() {
        let filter = MessageFilterState()
        #expect(filter.isActive == false)
        #expect(filter.activeFilterCount == 0)
    }

    @Test("default state returns all messages")
    func defaultStateReturnsAll() {
        let filter = MessageFilterState()
        let messages = sampleMessages
        let result = filter.apply(to: messages)
        #expect(result.count == messages.count)
    }

    // MARK: - Payload Search

    @Test("payload search matches payload content case-insensitively")
    func payloadSearchMatchesPayload() {
        var filter = MessageFilterState()
        filter.payloadSearchText = "state"
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == 1)
        #expect(result[0].topic == "control/light")
    }

    @Test("payload search matches topic")
    func payloadSearchMatchesTopic() {
        var filter = MessageFilterState()
        filter.payloadSearchText = "humidity"
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == 1)
        #expect(result[0].topic == "sensors/humidity")
    }

    @Test("payload search is case-insensitive")
    func payloadSearchCaseInsensitive() {
        var filter = MessageFilterState()
        filter.payloadSearchText = "STATE"
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == 1)
    }

    @Test("payload search sets isActive")
    func payloadSearchSetsActive() {
        var filter = MessageFilterState()
        filter.payloadSearchText = "test"
        #expect(filter.isActive == true)
        #expect(filter.activeFilterCount == 1)
    }

    // MARK: - QoS Filter

    @Test("QoS filter excludes deselected levels")
    func qosFilterExcludes() {
        var filter = MessageFilterState()
        filter.selectedQoSLevels = [.atMostOnce]
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.qos == .atMostOnce })
    }

    @Test("QoS filter with no levels returns empty")
    func qosFilterNoLevels() {
        var filter = MessageFilterState()
        filter.selectedQoSLevels = []
        let result = filter.apply(to: sampleMessages)
        #expect(result.isEmpty)
    }

    @Test("QoS filter sets isActive")
    func qosFilterSetsActive() {
        var filter = MessageFilterState()
        filter.selectedQoSLevels = [.atMostOnce, .atLeastOnce]
        #expect(filter.isActive == true)
        #expect(filter.activeFilterCount == 1)
    }

    // MARK: - Retained Filter

    @Test("retained filter shows only retained")
    func retainedFilterShowsRetained() {
        var filter = MessageFilterState()
        filter.showRetained = true
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == 1)
        #expect(result[0].retained == true)
    }

    @Test("retained filter shows only non-retained")
    func retainedFilterShowsNonRetained() {
        var filter = MessageFilterState()
        filter.showRetained = false
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == 3)
        #expect(result.allSatisfy { !$0.retained })
    }

    @Test("retained nil shows all")
    func retainedNilShowsAll() {
        var filter = MessageFilterState()
        filter.showRetained = nil
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == sampleMessages.count)
    }

    // MARK: - Direction Filter

    @Test("direction filter shows only sent")
    func directionFilterShowsSent() {
        var filter = MessageFilterState()
        filter.showSentByMe = true
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == 1)
        #expect(result[0].sentByMe == true)
    }

    @Test("direction filter shows only received")
    func directionFilterShowsReceived() {
        var filter = MessageFilterState()
        filter.showSentByMe = false
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == 3)
        #expect(result.allSatisfy { !$0.sentByMe })
    }

    // MARK: - Time Range Filter

    @Test("time range filters old messages")
    func timeRangeFiltersOld() {
        let now = Date()
        let messages = [
            makeMessage(topic: "recent", payload: "a", timestamp: now.addingTimeInterval(-30)),
            makeMessage(topic: "old", payload: "b", timestamp: now.addingTimeInterval(-120)),
        ]
        var filter = MessageFilterState()
        filter.timeRange = .oneMinute
        let result = filter.apply(to: messages)
        #expect(result.count == 1)
        #expect(result[0].topic == "recent")
    }

    @Test("time range .all returns all")
    func timeRangeAllReturnsAll() {
        let now = Date()
        let messages = [
            makeMessage(topic: "recent", payload: "a", timestamp: now),
            makeMessage(topic: "old", payload: "b", timestamp: now.addingTimeInterval(-86400)),
        ]
        var filter = MessageFilterState()
        filter.timeRange = .all
        let result = filter.apply(to: messages)
        #expect(result.count == 2)
    }

    // MARK: - Composed Filters

    @Test("multiple filters compose correctly")
    func composedFilters() {
        var filter = MessageFilterState()
        filter.selectedQoSLevels = [.atMostOnce]
        filter.showSentByMe = false
        filter.payloadSearchText = "22"
        let result = filter.apply(to: sampleMessages)
        #expect(result.count == 1)
        #expect(result[0].topic == "sensors/temp")
        #expect(result[0].payloadString == "22.5")
    }

    @Test("activeFilterCount counts all active filters")
    func activeFilterCountMultiple() {
        var filter = MessageFilterState()
        filter.payloadSearchText = "test"
        filter.selectedQoSLevels = [.atMostOnce]
        filter.showRetained = true
        filter.showSentByMe = false
        filter.timeRange = .oneHour
        #expect(filter.activeFilterCount == 5)
    }

    // MARK: - Reset

    @Test("reset restores defaults")
    func resetRestoresDefaults() {
        var filter = MessageFilterState()
        filter.payloadSearchText = "test"
        filter.selectedQoSLevels = [.atMostOnce]
        filter.showRetained = true
        filter.showSentByMe = false
        filter.timeRange = .oneHour

        filter.reset()

        #expect(filter.isActive == false)
        #expect(filter.activeFilterCount == 0)
        #expect(filter.payloadSearchText.isEmpty)
        #expect(filter.selectedQoSLevels == Set(QoSLevel.allCases))
        #expect(filter.showRetained == nil)
        #expect(filter.showSentByMe == nil)
        #expect(filter.timeRange == .all)
    }
}
