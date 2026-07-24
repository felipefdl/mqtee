//
//  LicensesSettingsView.swift
//  mqtee
//

import SwiftUI

struct LicensesSettingsView: View {
    @State private var licenses: [LicenseEntry] = []

    var body: some View {
        List(licenses) { entry in
            NavigationLink {
                LicenseDetailView(entry: entry)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.packageName)
                            .fontWeight(.medium)
                        Spacer()
                        Text(entry.packageVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.license)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Open Source Licenses")
        .task {
            if licenses.isEmpty {
                licenses = LicenseBundle.load()
            }
        }
    }
}

struct LicenseDetailView: View {
    let entry: LicenseEntry

    var body: some View {
        ScrollView {
            Text(entry.displayLicenseText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(entry.packageName)
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
}
