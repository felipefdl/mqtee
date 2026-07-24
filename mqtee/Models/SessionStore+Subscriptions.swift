import Foundation

extension SessionStore {
    func subscribe(
        to topic: String,
        qos: QoSLevel = .atMostOnce,
        noLocal: Bool = false,
        retainAsPublished: Bool = false,
        retainHandling: RetainHandling = .sendOnSubscribe
    ) {
        guard !subscriptions.contains(where: { $0.topic == topic }) else { return }
        let color = SubscriptionColor.next(after: subscriptions.map(\.color))
        let subscription = Subscription(
            topic: topic,
            qos: qos,
            color: color,
            noLocal: noLocal,
            retainAsPublished: retainAsPublished,
            retainHandling: retainHandling
        )
        subscriptions.append(subscription)
        topicColorCache.removeAll()
        persistSubscriptions()
        topicTree.ensureTopic(topic)

        logStore.logSubscription(
            "Subscribing",
            level: .info,
            topic: topic,
            details: "QoS: \(qos.rawValue)",
            connectionId: connection.id
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                let config = MQTTSubscriptionConfig(
                    topic: topic,
                    qos: qos,
                    noLocal: noLocal,
                    retainAsPublished: retainAsPublished,
                    retainHandling: UInt8(retainHandling.rawValue)
                )
                try mqttService.subscribe(topics: [config])
            } catch {
                logStore.logError(
                    "Subscribe failed for \(topic)",
                    details: error.localizedDescription,
                    connectionId: connection.id
                )
            }
        }
    }

    func resubscribeAll() {
        guard !subscriptions.isEmpty else { return }

        let configs = subscriptions.map {
            MQTTSubscriptionConfig(
                topic: $0.topic,
                qos: $0.qos,
                noLocal: $0.noLocal,
                retainAsPublished: $0.retainAsPublished,
                retainHandling: UInt8($0.retainHandling.rawValue)
            )
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try mqttService.subscribe(topics: configs)
            } catch {
                logStore.logError(
                    "Resubscribe failed",
                    details: error.localizedDescription,
                    connectionId: connection.id
                )
            }
        }
    }

    func removeMessages(where predicate: (MQTTMessage) -> Bool) {
        messages.removeAll(where: predicate)
        rebuildMessagesByTopic()

        topicTree.clear()
        topicTree.addMessages(messages)
        ensureSubscriptionTopicsInTree()

        messageVersion += 1
    }

    func unsubscribe(from subscriptionId: UUID) {
        guard let subscription = subscriptions.first(where: { $0.id == subscriptionId }) else { return }
        let topic = subscription.topic
        subscriptions.removeAll { $0.id == subscriptionId }
        topicColorCache.removeAll()
        persistSubscriptions()

        flushMessageBuffer()

        removeMessages { [self] message in
            topicMatchesPattern(topic: message.topic, pattern: topic)
                && !subscriptions.contains { sub in
                    topicMatchesPattern(topic: message.topic, pattern: sub.topic)
                }
        }

        logStore.logSubscription(
            "Unsubscribing",
            level: .info,
            topic: topic,
            connectionId: connection.id
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                try mqttService.unsubscribe(topics: [topic])
            } catch {
                logStore.logError(
                    "Unsubscribe failed for \(topic)",
                    details: error.localizedDescription,
                    connectionId: connection.id
                )
            }
        }
    }

    func unsubscribeByTopic(_ topic: String) {
        // Find subscriptions that match this topic or cover paths under it
        let matchingSubscriptions = subscriptions.filter { subscription in
            topicMatchesPattern(topic: topic, pattern: subscription.topic) ||
            subscription.topic.hasPrefix(topic + "/")
        }

        let removedPatterns = matchingSubscriptions.map(\.topic)
        for subscription in matchingSubscriptions {
            subscriptions.removeAll { $0.id == subscription.id }
        }
        topicColorCache.removeAll()
        persistSubscriptions()

        flushMessageBuffer()

        removeMessages { [self] message in
            let matchesRemovedPattern = removedPatterns.contains { pattern in
                topicMatchesPattern(topic: message.topic, pattern: pattern)
            }
            let matchesExactOrChild = message.topic == topic || message.topic.hasPrefix(topic + "/")
            let wouldBeRemoved = matchesRemovedPattern || matchesExactOrChild
            let coveredByRemaining = subscriptions.contains { sub in
                topicMatchesPattern(topic: message.topic, pattern: sub.topic)
            }
            return wouldBeRemoved && !coveredByRemaining
        }

        if !matchingSubscriptions.isEmpty {
            let topics = matchingSubscriptions.map(\.topic)
            Task { [weak self] in
                guard let self else { return }
                do {
                    try mqttService.unsubscribe(topics: topics)
                } catch {
                    logStore.logError(
                        "Unsubscribe failed",
                        details: error.localizedDescription,
                        connectionId: connection.id
                    )
                }
            }
        }
    }
}
