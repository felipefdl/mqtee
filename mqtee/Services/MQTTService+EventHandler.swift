import Foundation

// MARK: - Event Handler

extension MQTTService {
    /// Batch messages on a background serial queue, dispatch one Task per batch to the main actor.
    /// Prevents flooding the main actor with one Task per MQTT message under high throughput.
    func enqueueBatchedMessage(_ message: MQTTMessage) {
        batchQueue.async { [weak self] in
            guard let self else { return }
            self.pendingMessages.append(message)
            guard !self.batchFlushScheduled else { return }
            self.batchFlushScheduled = true
            self.batchQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                let batch = self.pendingMessages
                self.pendingMessages.removeAll(keepingCapacity: true)
                self.batchFlushScheduled = false
                guard !batch.isEmpty else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.delegate?.mqttDidReceiveMessages(batch)
                }
            }
        }
    }

    func onEvent(event: ConnectionEvent) {
        // Construct MQTTMessage off MainActor for .messageReceived (JSON parsing, date formatting)
        if case .messageReceived(let message) = event {
            let swiftMessage = MQTTMessage(
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
            enqueueBatchedMessage(swiftMessage)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            switch event {
            case .connected:
                self.delegate?.mqttDidConnect()

            case .disconnected(let reason, let reasonCode):
                self.delegate?.mqttDidDisconnect(reason: reason, reasonCode: reasonCode)

            case .messageReceived:
                break // Handled above

            case .subscribeAck(let packetId, let returnCodes, let reasonCodesDetail):
                self.delegate?.mqttDidSubscribe(
                    packetId: packetId,
                    returnCodes: returnCodes,
                    reasonCodesDetail: reasonCodesDetail
                )

            case .unsubscribeAck(let packetId):
                self.delegate?.mqttDidUnsubscribe(packetId: packetId)

            case .publishAck(let packetId):
                self.delegate?.mqttDidPublish(packetId: packetId)

            case .error(let error):
                self.delegate?.mqttDidEncounterError(error)

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
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "CONNACK",
                    details: details,
                    direction: .incoming
                )

            case .pubRecReceived(let packetId):
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "PUBREC received",
                    details: "Packet ID: \(packetId)",
                    direction: .incoming
                )

            case .pubRelReceived(let packetId):
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "PUBREL received",
                    details: "Packet ID: \(packetId)",
                    direction: .incoming
                )

            case .pubCompReceived(let packetId):
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "PUBCOMP received",
                    details: "Packet ID: \(packetId)",
                    direction: .incoming
                )

            case .pingResponseReceived:
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "PINGRESP received",
                    details: nil,
                    direction: .incoming
                )

            case .publishSent(let packetId):
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "PUBLISH sent",
                    details: "Packet ID: \(packetId)",
                    direction: .outgoing
                )

            case .subscribeSent(let packetId):
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "SUBSCRIBE sent",
                    details: "Packet ID: \(packetId)",
                    direction: .outgoing
                )

            case .unsubscribeSent(let packetId):
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "UNSUBSCRIBE sent",
                    details: "Packet ID: \(packetId)",
                    direction: .outgoing
                )

            case .publishAckSent(let packetId):
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "PUBACK sent",
                    details: "Packet ID: \(packetId)",
                    direction: .outgoing
                )

            case .pubRecSent(let packetId):
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "PUBREC sent",
                    details: "Packet ID: \(packetId)",
                    direction: .outgoing
                )

            case .pubCompSent(let packetId):
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "PUBCOMP sent",
                    details: "Packet ID: \(packetId)",
                    direction: .outgoing
                )

            case .pingSent:
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "PINGREQ sent",
                    details: nil,
                    direction: .outgoing
                )

            case .disconnectSent:
                self.delegate?.mqttDidReceiveProtocolEvent(
                    type: "DISCONNECT sent",
                    details: nil,
                    direction: .outgoing
                )
            }
        }
    }
}
