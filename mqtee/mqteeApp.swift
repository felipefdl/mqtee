//
//  mqteeApp.swift
//  mqtee
//
//  Created by Felipe Lima on 2/12/26.
//

import SwiftUI

@main
struct mqteeApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.contentMinSize)
        .commands {
            MQTeeCommands(openWindow: openWindow)
        }
        #endif

        #if os(macOS)
        Settings {
            GeneralSettingsView()
                .frame(width: 500)
                .fixedSize(horizontal: false, vertical: true)
        }

        Window("Open Source Licenses", id: "licenses") {
            NavigationStack {
                LicensesSettingsView()
            }
        }
        .defaultSize(width: 500, height: 500)

        WindowGroup(id: "event-log", for: EventLogWindowValue.self) { $value in
            if let value {
                LogView(logStore: LogStore.shared, connectionId: value.connectionId)
                    .navigationTitle("Event Log — \(value.connectionName)")
            }
        }
        .defaultSize(width: 700, height: 400)
        #endif
    }
}
