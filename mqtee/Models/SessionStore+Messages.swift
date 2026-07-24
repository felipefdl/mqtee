import Foundation

extension SessionStore {
    func receiveMessage(_ message: MQTTMessage) {
        if message.sentByMe {
            let matchesSubscription = subscriptions.contains { sub in
                topicMatchesPattern(topic: message.topic, pattern: sub.topic)
            }
            if !matchesSubscription { return }
        }
        messages.append(message)
        messagesByTopic[message.topic, default: []].append(message)
        invalidateMessageCache()
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
            rebuildMessagesByTopic()
            let survivingIds = Set(messages.map(\.id))
            topicTree.trimMessages(retaining: survivingIds)
        }
        topicTree.addMessage(message)
        topicTree.treeVersion += 1
        messageVersion += 1
    }

    func receiveMessages(_ batch: [MQTTMessage]) {
        // Discard messages that don't match any active subscription
        let filtered = batch.filter { message in
            subscriptions.contains { sub in
                topicMatchesPattern(topic: message.topic, pattern: sub.topic)
            }
        }
        guard !filtered.isEmpty else { return }

        messages.append(contentsOf: filtered)
        for message in filtered {
            messagesByTopic[message.topic, default: []].append(message)
        }
        invalidateMessageCache()
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
            rebuildMessagesByTopic()
            let survivingIds = Set(messages.map(\.id))
            topicTree.trimMessages(retaining: survivingIds)
        }
        topicTree.addMessages(filtered, incrementVersion: false)
        scheduleUIFlush()
    }

    func flushMessageBuffer() {
        guard !isStopped else {
            messageBuffer.removeAll()
            messageFlushTask = nil
            return
        }
        guard !messageBuffer.isEmpty else {
            messageFlushTask = nil
            return
        }

        let batch = messageBuffer
        messageBuffer.removeAll(keepingCapacity: true)
        messageFlushTask = nil

        if batch.count < batchLogThreshold {
            for message in batch {
                let payloadPreview = String(data: message.payload.prefix(4096), encoding: .utf8)
                    ?? "[\(message.payload.count) bytes, non-UTF8]"
                logStore.logMessage(
                    "Message received",
                    level: .debug,
                    topic: message.topic,
                    details: "QoS: \(message.qos.rawValue), Retained: \(message.retained), Size: \(message.payload.count) bytes\nPayload: \(payloadPreview)",
                    direction: .incoming,
                    connectionId: connection.id
                )
            }
        } else {
            logStore.logMessage(
                "Received \(batch.count) messages",
                level: .debug,
                details: "Topics: \(Set(batch.map(\.topic)).count) unique",
                direction: .incoming,
                connectionId: connection.id
            )
        }

        receiveMessages(batch)
    }

    func scheduleMessageFlush() {
        guard messageFlushTask == nil else { return }
        messageFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await self?.flushMessageBuffer()
        }
    }

    func scheduleUIFlush() {
        pendingUIUpdate = true
        guard uiFlushTask == nil else { return }
        uiFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await self?.flushUIUpdate()
        }
    }

    private func flushUIUpdate() {
        uiFlushTask = nil
        guard pendingUIUpdate else { return }
        pendingUIUpdate = false
        topicTree.treeVersion += 1
        messageVersion += 1
    }

    func clearMessages() {
        messageFlushTask?.cancel()
        messageFlushTask = nil
        uiFlushTask?.cancel()
        uiFlushTask = nil
        messageBuffer.removeAll()

        messages.removeAll()
        messagesByTopic.removeAll()
        invalidateMessageCache()
        topicTree.clear()
        messageVersion += 1
        ensureSubscriptionTopicsInTree()
    }

    func clearMessagesForTopic(_ topic: String) {
        flushMessageBuffer()
        invalidateMessageCache()
        removeMessages { message in
            message.topic == topic || message.topic.hasPrefix(topic + "/")
        }
    }

    func clearMessagesForSubscription(_ subscription: Subscription) {
        flushMessageBuffer()
        invalidateMessageCache()
        removeMessages { [self] message in
            topicMatchesPattern(topic: message.topic, pattern: subscription.topic)
        }
    }
}
