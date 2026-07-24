//
//  ResetDataSheet.swift
//  mqtee
//

import SwiftUI

struct ResetDataSheet: View {
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var confirmText = ""
    @State private var didConfirm = false

    private var isConfirmed: Bool {
        confirmText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE"
    }

    var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
    private var macOSBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reset All Data").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                sheetContent
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Reset All Data") { performReset() }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .disabled(!isConfirmed)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 420)
    }
    #endif

    // MARK: - iOS

    #if !os(macOS)
    private var iOSBody: some View {
        NavigationStack {
            Form {
                Section { sheetContent }
            }
            .navigationTitle("Reset All Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset All Data") { performReset() }
                        .foregroundStyle(.red)
                        .disabled(!isConfirmed)
                }
            }
        }
    }
    #endif

    // MARK: - Content

    @ViewBuilder
    private var sheetContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.title2)
            Text("This will permanently delete all connections, credentials, sessions, messages, and settings.")
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("Type DELETE to confirm:")
                .font(.callout)
            confirmTextField
        }
    }

    private var confirmTextField: some View {
        TextField("DELETE", text: $confirmText)
            .onSubmit { if isConfirmed { performReset() } }
            #if os(macOS)
            .textFieldStyle(.roundedBorder)
            #endif
    }

    private func performReset() {
        guard !didConfirm else { return }
        didConfirm = true
        onConfirm()
        dismiss()
    }
}
