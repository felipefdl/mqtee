import Foundation

// MARK: - Event Handler

extension MQTTService {
    /// Delay used to coalesce bursts of messages into one delegate call.
    private static let batchInterval: Duration = .milliseconds(100)

    func onEvent(event: ConnectionEvent) {
        // Construct MQTTMessage off MainActor for .messageReceived (JSON parsing, date formatting)
        let item: MQTTIngressItem
        if case .messageReceived(let message) = event {
            item = .message(
                MQTTMessage(
                    topic: message.topic,
                    payload: message.payload,
                    qos: QoSLevel.fromRust(message.qos),
                    retained: message.retain,
                    timestamp: Date(timeIntervalSince1970: Double(message.timestampMs) / 1000.0),
                    mqttContentType: message.contentType,
                    responseTopic: message.responseTopic,
                    correlationData: message.correlationData,
                    userProperties: message.userProperties.map { MQTTUserProperty(key: $0.key, value: $0.value) },
                    payloadFormatIndicator: message.payloadFormatIndicator,
                    messageExpiryInterval: message.messageExpiryInterval
                )
            )
        } else {
            item = .event(event)
        }

        guard case .drain(let delayed) = ingress.push(item) else { return }
        Task { @MainActor [weak self] in
            if delayed {
                try? await Task.sleep(for: Self.batchInterval)
            }
            self?.drainIngress()
        }
    }

    /// Delivers everything buffered, in arrival order. Consecutive messages are coalesced into one batch.
    @MainActor
    private func drainIngress() {
        let drain = ingress.take()
        if drain.dropped > 0 {
            LogStore.shared.logConnection(
                "Dropped \(drain.dropped) incoming messages",
                level: .warning,
                details: "Message ingress exceeded the in-memory message limit before the UI could process it",
                direction: .incoming,
                connectionId: ingressConnectionId
            )
        }

        var batch: [MQTTMessage] = []
        for item in drain.items {
            switch item {
            case .message(let message):
                batch.append(message)
            case .event(let event):
                if !batch.isEmpty {
                    delegate?.mqttDidReceiveMessages(batch)
                    batch.removeAll(keepingCapacity: true)
                }
                dispatch(event)
            }
        }
        if !batch.isEmpty {
            delegate?.mqttDidReceiveMessages(batch)
        }
    }

    @MainActor private func dispatch(_ event: ConnectionEvent) {
        switch event {
        case .connected:
            delegate?.mqttDidConnect()

        case .disconnected(let reason, let reasonCode):
            delegate?.mqttDidDisconnect(reason: reason, reasonCode: reasonCode)

        case .messageReceived:
            break // Queued as a message item in onEvent

        case .subscribeAck(let packetId, let returnCodes, let reasonCodesDetail):
            delegate?.mqttDidSubscribe(
                packetId: packetId,
                returnCodes: returnCodes,
                reasonCodesDetail: reasonCodesDetail
            )

        case .unsubscribeAck(let packetId):
            delegate?.mqttDidUnsubscribe(packetId: packetId)

        case .publishAck(let packetId):
            delegate?.mqttDidPublish(packetId: packetId)

        case .error(let error):
            delegate?.mqttDidEncounterError(error)

        case .connAckDetails(
            let sessionPresent, let returnCode, let reasonString,
            let assignedClientId, let serverKeepAlive, let maximumQos,
            let retainAvailable, let wildcardSubscriptionAvailable,
            let subscriptionIdentifiersAvailable, let sharedSubscriptionAvailable,
            let maximumPacketSize
        ):
            var details = "Session present: \(sessionPresent), Return code: \(returnCode)"
            if let reasonString { details += ", Reason: \(reasonString)" }
            if let assignedClientId { details += ", Assigned client ID: \(assignedClientId)" }
            if let serverKeepAlive { details += ", Server keep alive: \(serverKeepAlive)s" }
            if let maximumQos { details += ", Max QoS: \(maximumQos)" }
            if let retainAvailable { details += ", Retain available: \(retainAvailable)" }
            if let wildcardSubscriptionAvailable { details += ", Wildcard sub: \(wildcardSubscriptionAvailable)" }
            if let subscriptionIdentifiersAvailable { details += ", Sub IDs: \(subscriptionIdentifiersAvailable)" }
            if let sharedSubscriptionAvailable { details += ", Shared sub: \(sharedSubscriptionAvailable)" }
            if let maximumPacketSize { details += ", Max packet size: \(maximumPacketSize)" }
            delegate?.mqttDidReceiveProtocolEvent(type: "CONNACK", details: details, direction: .incoming)

        case .pubRecReceived(let packetId):
            delegate?.mqttDidReceiveProtocolEvent(
                type: "PUBREC received", details: "Packet ID: \(packetId)", direction: .incoming
            )

        case .pubRelReceived(let packetId):
            delegate?.mqttDidReceiveProtocolEvent(
                type: "PUBREL received", details: "Packet ID: \(packetId)", direction: .incoming
            )

        case .pubCompReceived(let packetId):
            delegate?.mqttDidReceiveProtocolEvent(
                type: "PUBCOMP received", details: "Packet ID: \(packetId)", direction: .incoming
            )

        case .pingResponseReceived:
            delegate?.mqttDidReceiveProtocolEvent(type: "PINGRESP received", details: nil, direction: .incoming)

        case .publishSent(let packetId):
            delegate?.mqttDidReceiveProtocolEvent(
                type: "PUBLISH sent", details: "Packet ID: \(packetId)", direction: .outgoing
            )

        case .subscribeSent(let packetId):
            delegate?.mqttDidReceiveProtocolEvent(
                type: "SUBSCRIBE sent", details: "Packet ID: \(packetId)", direction: .outgoing
            )

        case .unsubscribeSent(let packetId):
            delegate?.mqttDidReceiveProtocolEvent(
                type: "UNSUBSCRIBE sent", details: "Packet ID: \(packetId)", direction: .outgoing
            )

        case .publishAckSent(let packetId):
            delegate?.mqttDidReceiveProtocolEvent(
                type: "PUBACK sent", details: "Packet ID: \(packetId)", direction: .outgoing
            )

        case .pubRecSent(let packetId):
            delegate?.mqttDidReceiveProtocolEvent(
                type: "PUBREC sent", details: "Packet ID: \(packetId)", direction: .outgoing
            )

        case .pubCompSent(let packetId):
            delegate?.mqttDidReceiveProtocolEvent(
                type: "PUBCOMP sent", details: "Packet ID: \(packetId)", direction: .outgoing
            )

        case .pingSent:
            delegate?.mqttDidReceiveProtocolEvent(type: "PINGREQ sent", details: nil, direction: .outgoing)

        case .disconnectSent:
            delegate?.mqttDidReceiveProtocolEvent(type: "DISCONNECT sent", details: nil, direction: .outgoing)
        }
    }
}
