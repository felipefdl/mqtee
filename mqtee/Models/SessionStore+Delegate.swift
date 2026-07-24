import Foundation

extension SessionStore: MQTTServiceDelegate {
    func mqttDidConnect() {
        guard !isStopped else { return }
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0
        isReconnecting = false

        isConnected = true
        isConnecting = false
        connectionError = nil
        connectedSince = Date()

        logStore.logConnection(
            "Connected to \(connection.host):\(connection.port)",
            level: .info,
            connectionId: connection.id
        )

        // Auto-resubscribe to persisted subscriptions
        if connection.persistSession && !subscriptions.isEmpty {
            resubscribeAll()
        }

        // Auto-subscribe to all topics if enabled
        if connection.autoSubscribe {
            let alreadySubscribed = Set(subscriptions.map(\.topic))
            if !alreadySubscribed.contains("#") {
                subscribe(to: "#", qos: .atMostOnce)
            }
            if !alreadySubscribed.contains("$SYS/#") {
                subscribe(to: "$SYS/#", qos: .atMostOnce)
            }
        }
    }

    func mqttDidDisconnect(reason: String, reasonCode: String?) {
        guard !isStopped else { return }
        let wasConnecting = isConnecting
        isConnected = false
        isConnecting = false
        connectedSince = nil

        let isUserRequested = reason == "User requested disconnect"
        let detailText = if let reasonCode {
            "\(reason) (code: \(reasonCode))"
        } else {
            reason
        }

        if !isUserRequested && wasConnecting {
            logStore.logError(
                "Connection failed",
                details: detailText,
                connectionId: connection.id
            )
        } else {
            logStore.logConnection(
                "Disconnected",
                level: isUserRequested ? .info : .warning,
                details: detailText,
                connectionId: connection.id
            )
        }

        if !isUserRequested && !pendingReconnect {
            connectionError = reason
        }

        if pendingReconnect {
            pendingReconnect = false
            connect()
        } else if !isUserRequested && !isStopped {
            scheduleAutoReconnect()
        }
    }

    func mqttDidReceiveMessage(_ message: MQTTMessage) {
        guard !isStopped else { return }
        messageBuffer.append(message)
        if messageBuffer.count >= maxMessages {
            flushMessageBuffer()
        } else {
            scheduleMessageFlush()
        }
    }

    func mqttDidReceiveMessages(_ messages: [MQTTMessage]) {
        guard !isStopped else { return }
        messageBuffer.append(contentsOf: messages)
        if messageBuffer.count >= maxMessages {
            flushMessageBuffer()
        } else {
            scheduleMessageFlush()
        }
    }

    func mqttDidSubscribe(packetId: UInt16, returnCodes: String, reasonCodesDetail: String?) {
        guard !isStopped else { return }
        var detailsText = "Return codes: \(returnCodes)"
        if let reasonCodesDetail { detailsText += " (\(reasonCodesDetail))" }
        logStore.logSubscription(
            "SUBACK received (packet \(packetId))",
            level: .debug,
            details: detailsText,
            direction: .incoming,
            connectionId: connection.id
        )
    }

    func mqttDidUnsubscribe(packetId: UInt16) {
        guard !isStopped else { return }
        logStore.logSubscription(
            "UNSUBACK received (packet \(packetId))",
            level: .debug,
            direction: .incoming,
            connectionId: connection.id
        )
    }

    func mqttDidPublish(packetId: UInt16) {
        guard !isStopped else { return }
        logStore.logPublish(
            "PUBACK received (packet \(packetId))",
            level: .debug,
            direction: .incoming,
            connectionId: connection.id
        )
    }

    func mqttDidEncounterError(_ error: String) {
        guard !isStopped else { return }
        logStore.logError(
            "MQTT error",
            details: error,
            connectionId: connection.id
        )
        connectionError = error
    }

    func mqttDidReceiveProtocolEvent(type: String, details: String?, direction: PacketDirection) {
        guard !isStopped else { return }
        let category: LogCategory = switch type {
        case "CONNACK", "DISCONNECT sent":
            .connection
        case "PINGREQ sent", "PINGRESP received":
            .keepAlive
        case "SUBSCRIBE sent", "SUBACK received", "UNSUBSCRIBE sent", "UNSUBACK received":
            .subscription
        default:
            .publish
        }

        logStore.log(
            level: .debug,
            category: category,
            message: type,
            details: details,
            direction: direction,
            connectionId: connection.id
        )
    }
}
