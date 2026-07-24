import SwiftUI

extension PublishPanelContent {
    func performPublish() {
        guard !topic.isEmpty else { return }

        let pubContentType = mqttContentType.isEmpty ? nil : mqttContentType
        let pubResponseTopic = responseTopic.isEmpty ? nil : responseTopic
        let pubCorrelationData: Data? = if correlationData.isEmpty {
            nil
        } else {
            dataFromHexString(correlationData)
        }
        let pubExpiryInterval: UInt32? = if let val = UInt32(messageExpiryInterval) {
            val
        } else {
            nil
        }
        let pubFormatIndicator: UInt8? = if payloadFormatIndicator == .unspecified {
            nil
        } else {
            UInt8(payloadFormatIndicator.rawValue)
        }
        let pubUserProperties = userProperties.filter { !$0.key.isEmpty }

        let result: Result<Void, Error>
        if payloadFormat == .hex, let data = dataFromHexString(payload) {
            result = session.publishData(
                topic: topic,
                payload: data,
                qos: qos,
                retain: retain,
                mqttContentType: pubContentType,
                responseTopic: pubResponseTopic,
                correlationData: pubCorrelationData,
                messageExpiryInterval: pubExpiryInterval,
                payloadFormatIndicator: pubFormatIndicator,
                userProperties: pubUserProperties
            )
        } else if payloadFormat == .base64 {
            let stripped = payload.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
            guard let data = Data(base64Encoded: stripped) else { return }
            result = session.publishData(
                topic: topic,
                payload: data,
                qos: qos,
                retain: retain,
                mqttContentType: pubContentType,
                responseTopic: pubResponseTopic,
                correlationData: pubCorrelationData,
                messageExpiryInterval: pubExpiryInterval,
                payloadFormatIndicator: pubFormatIndicator,
                userProperties: pubUserProperties
            )
        } else {
            result = session.publish(
                topic: topic,
                message: payload,
                qos: qos,
                retain: retain,
                mqttContentType: pubContentType,
                responseTopic: pubResponseTopic,
                correlationData: pubCorrelationData,
                messageExpiryInterval: pubExpiryInterval,
                payloadFormatIndicator: pubFormatIndicator,
                userProperties: pubUserProperties
            )
        }
        feedbackTask?.cancel()
        withAnimation(BrandTheme.springSnappy) {
            switch result {
            case .success:
                publishFeedback = .success
            case .failure(let error):
                publishFeedback = .failure(error.localizedDescription)
            }
        }
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(BrandTheme.springSnappy) {
                publishFeedback = nil
            }
        }
    }

    var publishButtonTint: Color? {
        switch publishFeedback {
        case .success: .green
        case .failure: .red
        case nil: nil
        }
    }

    @ViewBuilder
    var publishButtonLabel: some View {
        switch publishFeedback {
        case .success:
            Label("Sent", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.white)
                .transition(.blurReplace)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.white)
                .lineLimit(1)
                .transition(.blurReplace)
        case nil:
            Label("Publish", systemImage: "paperplane.fill")
                .transition(.blurReplace)
        }
    }
}
