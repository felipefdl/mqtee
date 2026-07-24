//
//  MQTeeShortcutsProvider.swift
//  mqtee
//

import AppIntents

struct MQTeeShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PublishMessageIntent(),
            phrases: ["Publish MQTT message with \(.applicationName)"],
            shortTitle: "Publish MQTT",
            systemImageName: "arrow.up.message"
        )
        AppShortcut(
            intent: GetRetainedValueIntent(),
            phrases: ["Get MQTT value with \(.applicationName)"],
            shortTitle: "Get MQTT Value",
            systemImageName: "arrow.down.message"
        )
    }
}
