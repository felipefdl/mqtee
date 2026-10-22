import Foundation
import Synchronization

/// One entry of the ordered ingress queue: a received message or any other connection event.
/// `ConnectionEvent` is an immutable generated value type; it is never mutated after being enqueued.
enum MQTTIngressItem: @unchecked Sendable {
    case message(MQTTMessage)
    case event(ConnectionEvent)
}

/// Contents taken from the buffer by one main-actor drain.
struct MQTTIngressDrain {
    var items: [MQTTIngressItem] = []
    /// Messages discarded (oldest first) since the previous drain because the buffer exceeded its cap.
    var dropped = 0
}

/// Lock-protected, order-preserving queue between the Rust callback thread and the main actor.
///
/// Holds at most one outstanding drain request at a time and bounds the number of buffered
/// messages: once the count exceeds twice the limit the oldest messages are dropped (amortised O(1)),
/// and `take()` enforces the limit exactly. Non-message events are never dropped or reordered.
final class MQTTIngressBuffer: Sendable {
    enum Schedule {
        /// A drain is already outstanding; nothing to do.
        case none
        /// Caller must schedule a drain, optionally after the batching delay.
        case drain(delayed: Bool)
    }

    private struct State {
        var items: [MQTTIngressItem] = []
        var messageCount = 0
        var dropped = 0
        var drainScheduled = false
        var limit = 10_000

        mutating func trim(to limit: Int) {
            var toDrop = messageCount - limit
            guard toDrop > 0 else { return }
            dropped += toDrop
            messageCount = limit
            var kept: [MQTTIngressItem] = []
            kept.reserveCapacity(items.count - toDrop)
            for item in items {
                if toDrop > 0, case .message = item {
                    toDrop -= 1
                    continue
                }
                kept.append(item)
            }
            items = kept
        }
    }

    private let state = Mutex(State())

    func setLimit(_ limit: Int) {
        state.withLock { $0.limit = max(1, limit) }
    }

    func push(_ item: MQTTIngressItem) -> Schedule {
        state.withLock { state in
            var isMessage = false
            if case .message = item {
                isMessage = true
                state.messageCount += 1
            }
            state.items.append(item)
            if state.messageCount > state.limit * 2 {
                state.trim(to: state.limit)
            }
            guard !state.drainScheduled else { return .none }
            state.drainScheduled = true
            return .drain(delayed: isMessage)
        }
    }

    /// Takes everything buffered and clears the outstanding-drain flag so the next push schedules again.
    func take() -> MQTTIngressDrain {
        state.withLock { state in
            state.trim(to: state.limit)
            let drain = MQTTIngressDrain(items: state.items, dropped: state.dropped)
            state.items = []
            state.messageCount = 0
            state.dropped = 0
            state.drainScheduled = false
            return drain
        }
    }

    /// Discards buffered items (used on teardown). An already scheduled drain finds an empty buffer.
    func reset() {
        state.withLock { state in
            state.items = []
            state.messageCount = 0
            state.dropped = 0
        }
    }
}
