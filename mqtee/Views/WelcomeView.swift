//
//  WelcomeView.swift
//  mqtee
//

import SwiftUI

struct WelcomeView: View {
    var onNewConnection: () -> Void
    var onImport: () -> Void
    var onExport: () -> Void
    var exportDisabled: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Image("MQTeeLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.primary)

                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Welcome to ")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                        AppNameText(size: .largeTitle)
                    }

                    #if os(macOS)
                    Text("Your MQTT companion for macOS")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    #else
                    Text("Your MQTT companion")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    #endif
                }
            }

            HStack(spacing: 16) {
                Button(action: onNewConnection) {
                    Label("New Connection", systemImage: "plus.circle")
                }
                .buttonStyle(.glass)

                Button(action: onImport) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.glass)

                Button(action: onExport) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glass)
                .disabled(exportDisabled)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Spacer()

            Text(Bundle.main.appVersion)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
