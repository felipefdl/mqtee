import Foundation

extension SessionStore {
    func connect() {
        guard !isStopped, !isConnected, !isConnecting else { return }

        isConnecting = true
        connectionError = nil
        reconnectCancelled = false
        connectGeneration += 1
        let generation = connectGeneration

        let deviceClientId = MQTTService.deviceClientId(for: connection.id)
        logStore.logConnection(
            "Connecting to \(connection.host):\(connection.port)",
            level: .info,
            details: "Client ID: \(deviceClientId), MQTT \(connection.mqttVersion == .v5 ? "5.0" : "3.1.1")",
            connectionId: connection.id
        )

        let connectionSnapshot = connection
        let existingCredentials = credentials
        let service = mqttService
        Task.detached { [weak self] in
            // Load credentials from Keychain off the main thread (can take 2s+ with iCloud Keychain)
            let creds: ConnectionCredentials?
            if let existingCredentials {
                creds = existingCredentials
            } else {
                creds = try? KeychainService.shared.loadCredentials(for: connectionSnapshot.id)
            }

            // Re-check on the main actor, in the same turn as the connect call, so a session that
            // was closed or cancelled while credentials loaded can never start a client.
            await MainActor.run { [weak self] in
                guard let self, !isStopped, connectGeneration == generation else { return }
                if existingCredentials == nil {
                    credentials = creds
                }
                do {
                    let config = try MQTTConnectionConfig(from: connectionSnapshot, credentials: creds)
                    try service.connect(config: config)
                } catch {
                    connectionError = error.localizedDescription
                    isConnecting = false
                    logStore.logError(
                        "Connection failed",
                        details: error.localizedDescription,
                        connectionId: connection.id
                    )
                    if isReconnecting {
                        scheduleAutoReconnect()
                    }
                }
            }
        }
    }

    func cleanup() {
        isStopped = true
        connectGeneration += 1
        mqttService.delegate = nil

        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false

        messageFlushTask?.cancel()
        messageFlushTask = nil
        messageBuffer.removeAll()

        uiFlushTask?.cancel()
        uiFlushTask = nil
        messages.removeAll()
        messagesByTopic.removeAll()
        cachedTopicMessages.removeAll()
        topicTree.clear()
        topicColorCache.removeAll()

        if isConnected || isConnecting {
            do {
                try mqttService.disconnect()
            } catch {
                logStore.logError(
                    "Disconnect failed during cleanup",
                    details: error.localizedDescription,
                    connectionId: connection.id
                )
            }
        }
        isConnected = false
        isConnecting = false
        connectedSince = nil
        mqttService.teardown()
    }

    func disconnect() {
        guard isConnected || isReconnecting || isConnecting else { return }

        invalidateConnectAttempt()

        guard isConnected else { return }

        logStore.logConnection(
            "Disconnecting from \(connection.host)",
            level: .info,
            connectionId: connection.id
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                try mqttService.disconnect()
            } catch {
                logStore.logError(
                    "Disconnect failed",
                    details: error.localizedDescription,
                    connectionId: connection.id
                )
            }
        }
    }

    func reconnect() {
        if isConnected {
            pendingReconnect = true
            disconnect()
        } else {
            connect()
        }
    }

    func cancelAutoReconnect() {
        invalidateConnectAttempt()
    }

    /// Abandons any pending or in-flight connect/reconnect attempt: later results from it are
    /// ignored, a client it already created is disconnected, and no further reconnect is scheduled.
    private func invalidateConnectAttempt() {
        let hadPendingAttempt = isReconnecting || isConnecting
        connectGeneration += 1
        reconnectCancelled = true
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0
        isReconnecting = false
        if isConnecting {
            isConnecting = false
            try? mqttService.disconnect()
        }
        guard hadPendingAttempt else { return }
        logStore.logConnection(
            "Auto-reconnect cancelled",
            level: .info,
            connectionId: connection.id
        )
    }

    func scheduleAutoReconnect() {
        guard autoReconnectEnabled, !isStopped else { return }

        reconnectAttempt += 1
        isReconnecting = true

        let delay = Self.reconnectDelay(attempt: reconnectAttempt, baseInterval: reconnectIntervalSeconds)

        logStore.logConnection(
            "Auto-reconnect attempt \(reconnectAttempt) in \(delay)s",
            level: .info,
            connectionId: connection.id
        )

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }

    static let maxReconnectDelaySeconds = 60

    /// Exponential backoff capped at `maxReconnectDelaySeconds`. The exponent is clamped
    /// so the shift can never overflow, no matter how many attempts a long outage accrues.
    static func reconnectDelay(attempt: Int, baseInterval: Int) -> Int {
        let base = min(max(baseInterval, 1), maxReconnectDelaySeconds)
        let exponent = min(max(attempt - 1, 0), 6)
        return min(base << exponent, maxReconnectDelaySeconds)
    }
}
