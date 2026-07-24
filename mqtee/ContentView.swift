//
//  ContentView.swift
//  mqtee
//
//  Created by Felipe Lima on 2/12/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ConnectionManagerView()
            #if os(macOS)
            .frame(minWidth: 1250, minHeight: 550)
            #endif
            #if DEBUG
            .preferredColorScheme(Self.isScreenshotMode ? .dark : nil)
            #endif
    }

    #if DEBUG
    private static let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
        || ProcessInfo.processInfo.arguments.contains("--screenshot-welcome")
    #endif
}

#Preview {
    ContentView()
        .frame(width: 600, height: 450)
}
