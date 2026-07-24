//
//  WindowTabbingConfigurator.swift
//  mqtee
//

#if os(macOS)
import AppKit
import SwiftUI

@MainActor
enum WindowTabbingState {
    static var preferTabs = true
    static var pendingTabTarget: NSWindow? = nil
}

private let mainTabbingIdentifier = "com.mqtee.app.main"

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var observer: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureExistingMainWindows()
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleWindowDidBecomeKey(notification)
            }
        }
    }

    private func handleWindowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isMainWindow(window) else { return }

        window.tabbingIdentifier = mainTabbingIdentifier

        if !WindowTabbingState.preferTabs {
            window.tabbingMode = .automatic
            WindowTabbingState.preferTabs = true
            WindowTabbingState.pendingTabTarget = nil
            return
        }

        window.tabbingMode = .preferred

        if let target = WindowTabbingState.pendingTabTarget {
            WindowTabbingState.pendingTabTarget = nil
            window.orderOut(nil)
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            target.addTabbedWindow(window, ordered: .above)
            NSAnimationContext.endGrouping()
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func isMainWindow(_ window: NSWindow) -> Bool {
        if window is NSPanel { return false }
        let excluded = ["Open Source Licenses", "Settings", "MQTee Settings"]
        if !window.title.isEmpty {
            if excluded.contains(window.title) { return false }
            if window.title.hasPrefix("Event Log") { return false }
        }
        if let id = window.identifier?.rawValue,
           id.contains("settings") || id.contains("preferences") || id.contains("Settings") {
            return false
        }
        return true
    }

    private func configureExistingMainWindows() {
        for window in NSApp.windows where isMainWindow(window) {
            window.tabbingIdentifier = mainTabbingIdentifier
            window.tabbingMode = .preferred
        }
    }
}
#endif
