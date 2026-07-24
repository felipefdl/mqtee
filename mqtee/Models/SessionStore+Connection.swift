import Foundation

extension SessionStore {
    func connect() {
        guard !isConnected && !isConnecting else { return }

        isConnecting = true
        connectionError = nil

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
                await MainActor.run { [weak self] in
                    self?.credentials = creds
                }
            }

            let config = MQTTConnectionConfig(from: connectionSnapshot, credentials: creds)
            do {
                try service.connect(config: config)
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
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
        guard isConnected || isReconnecting else { return }

        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0
        isReconnecting = false

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
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0
        isReconnecting = false
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

        let baseInterval = reconnectIntervalSeconds
        let delay = min(baseInterval * Int(pow(2.0, Double(reconnectAttempt - 1))), 60)

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
}
