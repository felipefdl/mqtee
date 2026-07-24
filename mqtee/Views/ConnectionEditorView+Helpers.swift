//
//  ConnectionEditorView+Helpers.swift
//  mqtee
//

import SwiftUI
import UniformTypeIdentifiers

enum ConnectionTestStatus {
    case idle
    case testing
    case success
    case failure(String)
}

#if os(macOS)
enum EditorTab: CaseIterable {
    case general, auth, security, lastWill, advanced

    var label: String {
        switch self {
        case .general: "General"
        case .auth: "Auth"
        case .security: "Security"
        case .lastWill: "Last Will"
        case .advanced: "Advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "server.rack"
        case .auth: "person.badge.key"
        case .security: "lock.shield"
        case .lastWill: "exclamationmark.bubble"
        case .advanced: "gearshape.2"
        }
    }
}
#endif

#if !os(macOS)
private struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
            }
    }
}

extension View {
    func keyboardDismissable() -> some View {
        modifier(KeyboardDismissModifier())
    }
}
#endif

struct CertificateFilePicker: View {
    let label: String
    @Binding var data: Data?
    var hint: String? = nil

    @State private var showingFilePicker = false

    var body: some View {
        LabeledContent(label) {
            if let fileData = data {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(fileData.count) bytes")
                        .foregroundStyle(.secondary)
                    Button("Clear") {
                        data = nil
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Button(hint ?? "Select...") {
                    showingFilePicker = true
                }
                .buttonStyle(.borderless)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.data, .x509Certificate],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                data = try? Data(contentsOf: url)
            }
        }
    }
}
