import SwiftUI

#if os(macOS)
struct MQTeeCommands: Commands {
    @FocusedValue(\.selectedConnection) private var selectedConnection
    @FocusedValue(\.activeSession) private var activeSession
    @FocusedValue(\.sidebarMode) private var sidebarMode
    @FocusedValue(\.editConnection) private var editConnection
    @FocusedValue(\.deleteConnection) private var deleteConnection
    @FocusedValue(\.duplicateConnection) private var duplicateConnection
    @FocusedValue(\.connectToConnection) private var connectToConnection
    @FocusedValue(\.selectedMessage) private var selectedMessage
    @FocusedValue(\.selectedTopicNode) private var selectedTopicNode
    @FocusedValue(\.importConnections) private var importConnections
    @FocusedValue(\.exportConnections) private var exportConnections
    @FocusedValue(\.showPublishPanel) private var showPublishPanel
    @FocusedValue(\.resetAllData) private var resetAllData
    #if DEBUG
    @FocusedValue(\.resetAndAddSampleBrokers) private var resetAndAddSampleBrokers
    #endif

    let openWindow: OpenWindowAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") {
                WindowTabbingState.pendingTabTarget = NSApp.keyWindow
                openWindow(id: "main")
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("New Connection Window") {
                WindowTabbingState.preferTabs = false
                openWindow(id: "main")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Connect") {
                if let connection = selectedConnection {
                    connectToConnection?(connection)
                }
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .disabled(selectedConnection == nil || activeSession != nil)

            Button("Edit Connection...") {
                if let connection = selectedConnection {
                    editConnection?(connection)
                }
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(selectedConnection == nil)

            Button("Duplicate Connection") {
                if let connection = selectedConnection {
                    duplicateConnection?(connection)
                }
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(selectedConnection == nil)

            Button("Delete Connection") {
                if let connection = selectedConnection {
                    deleteConnection?(connection)
                }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(selectedConnection == nil)
        }

        CommandGroup(replacing: .importExport) {
            Button("Import Connections...") {
                importConnections?()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(importConnections == nil)

            Button("Export All Connections...") {
                exportConnections?()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(exportConnections == nil)

            Divider()

            Button("Reset All Data...") {
                resetAllData?()
            }
            .disabled(resetAllData == nil)
        }

        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Copy Message") {
                if let message = selectedMessage {
                    let text = MessageExportService.formatAsMarkdown(message)
                    MessageExportService.copyToClipboard(text)
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(selectedMessage == nil)

            Menu("Copy Message As...") {
                Button("Markdown") {
                    if let message = selectedMessage {
                        let text = MessageExportService.formatAsMarkdown(message)
                        MessageExportService.copyToClipboard(text)
                    }
                }
                Button("JSON") {
                    if let message = selectedMessage {
                        let text = MessageExportService.formatAsJSON(message)
                        MessageExportService.copyToClipboard(text)
                    }
                }
                Button("CSV") {
                    if let message = selectedMessage {
                        let text = MessageExportService.formatMessagesAsCSV([message])
                        MessageExportService.copyToClipboard(text)
                    }
                }
            }
            .disabled(selectedMessage == nil)

            Button("Copy Payload Only") {
                if let message = selectedMessage {
                    MessageExportService.copyToClipboard(message.payloadString)
                }
            }
            .disabled(selectedMessage == nil)
        }

        CommandMenu("Connection") {
            Button("Publish Message...") {
                activeSession?.showPublishPopover.toggle()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(activeSession == nil || showPublishPanel?.wrappedValue == true)

            Button("Send Publish") {
                activeSession?.triggerPublish = true
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(activeSession == nil || (showPublishPanel?.wrappedValue != true && activeSession?.showPublishPopover != true))

            Button("Prettify Payload") {
                activeSession?.triggerPrettify = true
            }
            .keyboardShortcut("j", modifiers: [.command, .shift])
            .disabled(activeSession == nil || (showPublishPanel?.wrappedValue != true && activeSession?.showPublishPopover != true))

            Divider()

            Button("Disconnect") {
                activeSession?.disconnect()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(activeSession == nil)

            Button("Reconnect") {
                activeSession?.reconnect()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(activeSession == nil || activeSession?.isConnected != true)

            Divider()

            Button("Clear All Messages") {
                activeSession?.clearMessages()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .disabled(activeSession == nil || (activeSession?.messages.isEmpty ?? true))
        }

        #if DEBUG
        CommandMenu("Debug") {
            Button("Reset & Add Sample Brokers") {
                resetAndAddSampleBrokers?()
            }
            .disabled(resetAndAddSampleBrokers == nil)
        }
        #endif

        CommandGroup(before: .help) {
            Button("Open Source Licenses") {
                openWindow(id: "licenses")
            }
        }

        CommandGroup(after: .toolbar) {
            Button("Event Log") {
                if let session = activeSession {
                    openWindow(
                        id: "event-log",
                        value: EventLogWindowValue(
                            connectionId: session.connection.id,
                            connectionName: session.connection.name
                        )
                    )
                }
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(activeSession == nil)

            Button("Toggle Publish Panel") {
                showPublishPanel?.wrappedValue.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(activeSession == nil)

            Divider()

            Button("Topics") {
                sidebarMode?.wrappedValue = .topics
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(activeSession == nil)

            Button("Subscriptions") {
                sidebarMode?.wrappedValue = .subscriptions
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(activeSession == nil)
        }

        CommandGroup(after: .windowArrangement) {
            ForEach(1...8, id: \.self) { index in
                Button("Show Tab \(index)") {
                    selectTab(at: index - 1)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
            }

            Button("Show Last Tab") {
                selectLastTab()
            }
            .keyboardShortcut("9", modifiers: .command)
        }
    }

    private func selectTab(at index: Int) {
        guard let window = NSApp.keyWindow,
              let tabs = window.tabbedWindows,
              index < tabs.count else { return }
        tabs[index].makeKeyAndOrderFront(nil)
    }

    private func selectLastTab() {
        guard let window = NSApp.keyWindow,
              let tabs = window.tabbedWindows,
              !tabs.isEmpty else { return }
        tabs.last?.makeKeyAndOrderFront(nil)
    }
}
#endif
