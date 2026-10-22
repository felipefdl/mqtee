import Testing
import Foundation
@testable import MQTee

@Suite("MQTTIngressBuffer")
struct MQTTIngressBufferTests {

    private func message(_ index: Int) -> MQTTIngressItem {
        .message(MQTTMessage(topic: "t/\(index)", payloadString: "\(index)"))
    }

    private func topics(_ drain: MQTTIngressDrain) -> [String] {
        drain.items.compactMap {
            if case .message(let message) = $0 { return message.topic }
            return nil
        }
    }

    @Test("Only the first push schedules a drain")
    func singleOutstandingDrain() {
        let buffer = MQTTIngressBuffer()
        guard case .drain(let delayed) = buffer.push(message(0)) else {
            Issue.record("First push must schedule a drain")
            return
        }
        #expect(delayed)
        guard case .none = buffer.push(message(1)) else {
            Issue.record("Second push must not schedule another drain")
            return
        }
        _ = buffer.take()
        guard case .drain = buffer.push(message(2)) else {
            Issue.record("Push after take must schedule again")
            return
        }
    }

    @Test("Drops oldest messages beyond the limit and counts them")
    func dropsOldest() {
        let buffer = MQTTIngressBuffer()
        buffer.setLimit(3)
        for index in 0..<10 {
            _ = buffer.push(message(index))
        }
        let drain = buffer.take()
        #expect(topics(drain) == ["t/7", "t/8", "t/9"])
        #expect(drain.dropped == 7)
        #expect(buffer.take().dropped == 0)
    }

    @Test("Events keep their position relative to retained messages")
    func eventOrdering() {
        let buffer = MQTTIngressBuffer()
        buffer.setLimit(2)
        _ = buffer.push(message(0))
        _ = buffer.push(message(1))
        _ = buffer.push(.event(.connected))
        _ = buffer.push(message(2))
        let drain = buffer.take()
        #expect(drain.dropped == 1)
        #expect(drain.items.count == 3)
        guard case .message(let first) = drain.items[0],
            case .event(.connected) = drain.items[1],
            case .message(let last) = drain.items[2]
        else {
            Issue.record("Unexpected item order")
            return
        }
        #expect(first.topic == "t/1")
        #expect(last.topic == "t/2")
    }
}
