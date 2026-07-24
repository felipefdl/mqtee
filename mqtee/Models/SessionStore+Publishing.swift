import Foundation

extension SessionStore {
    func publish(
        topic: String,
        message: String,
        qos: QoSLevel = .atMostOnce,
        retain: Bool = false,
        mqttContentType: String? = nil,
        responseTopic: String? = nil,
        correlationData: Data? = nil,
        messageExpiryInterval: UInt32? = nil,
        payloadFormatIndicator: UInt8? = nil,
        userProperties: [MQTTUserProperty] = []
    ) -> Result<Void, Error> {
        guard let data = message.data(using: .utf8) else {
            let error = MQTTServiceError.publishFailed("Invalid UTF-8 payload")
            logStore.logError(
                "Publish failed to \(topic)",
                details: error.localizedDescription,
                connectionId: connection.id
            )
            return .failure(error)
        }

        logStore.logPublish(
            "Publishing message",
            level: .info,
            topic: topic,
            details: "QoS: \(qos.rawValue), Retain: \(retain), Size: \(data.count) bytes\nPayload: \(message)",
            direction: .outgoing,
            connectionId: connection.id
        )

        do {
            try mqttService.publish(
                topic: topic,
                payload: data,
                qos: qos,
                retain: retain,
                contentType: mqttContentType,
                responseTopic: responseTopic,
                correlationData: correlationData,
                messageExpiryInterval: messageExpiryInterval,
                payloadFormatIndicator: payloadFormatIndicator,
                userProperties: userProperties.map { UserProperty(key: $0.key, value: $0.value) }
            )
            let sentMessage = MQTTMessage(
                topic: topic,
                payload: data,
                qos: qos,
                retained: retain,
                sentByMe: true,
                mqttContentType: mqttContentType,
                responseTopic: responseTopic,
                correlationData: correlationData,
                userProperties: userProperties,
                payloadFormatIndicator: payloadFormatIndicator,
                messageExpiryInterval: messageExpiryInterval
            )
            receiveMessage(sentMessage)
            return .success(())
        } catch {
            logStore.logError(
                "Publish failed to \(topic)",
                details: error.localizedDescription,
                connectionId: connection.id
            )
            return .failure(error)
        }
    }

    func publishData(
        topic: String,
        payload: Data,
        qos: QoSLevel = .atMostOnce,
        retain: Bool = false,
        mqttContentType: String? = nil,
        responseTopic: String? = nil,
        correlationData: Data? = nil,
        messageExpiryInterval: UInt32? = nil,
        payloadFormatIndicator: UInt8? = nil,
        userProperties: [MQTTUserProperty] = []
    ) -> Result<Void, Error> {
        let hexPreview = payload.prefix(256).map { String(format: "%02X", $0) }.joined(separator: " ")
        let truncated = payload.count > 256 ? "\(hexPreview)..." : hexPreview

        logStore.logPublish(
            "Publishing message",
            level: .info,
            topic: topic,
            details: "QoS: \(qos.rawValue), Retain: \(retain), Size: \(payload.count) bytes\nPayload (hex): \(truncated)",
            direction: .outgoing,
            connectionId: connection.id
        )

        do {
            try mqttService.publish(
                topic: topic,
                payload: payload,
                qos: qos,
                retain: retain,
                contentType: mqttContentType,
                responseTopic: responseTopic,
                correlationData: correlationData,
                messageExpiryInterval: messageExpiryInterval,
                payloadFormatIndicator: payloadFormatIndicator,
                userProperties: userProperties.map { UserProperty(key: $0.key, value: $0.value) }
            )
            let sentMessage = MQTTMessage(
                topic: topic,
                payload: payload,
                qos: qos,
                retained: retain,
                sentByMe: true,
                mqttContentType: mqttContentType,
                responseTopic: responseTopic,
                correlationData: correlationData,
                userProperties: userProperties,
                payloadFormatIndicator: payloadFormatIndicator,
                messageExpiryInterval: messageExpiryInterval
            )
            receiveMessage(sentMessage)
            return .success(())
        } catch {
            logStore.logError(
                "Publish failed to \(topic)",
                details: error.localizedDescription,
                connectionId: connection.id
            )
            return .failure(error)
        }
    }
}
