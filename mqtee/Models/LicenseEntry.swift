//
//  LicenseEntry.swift
//  mqtee
//

import Foundation

struct LicenseEntry: Codable, Identifiable {
    let packageName: String
    let packageVersion: String
    let repository: String?
    let license: String
    let licenses: [LicenseText]

    var id: String { "\(packageName)-\(packageVersion)" }

    var displayLicenseText: String {
        licenses.map(\.text).joined(separator: "\n\n---\n\n")
    }

    struct LicenseText: Codable {
        let license: String
        let text: String
    }

    enum CodingKeys: String, CodingKey {
        case packageName = "package_name"
        case packageVersion = "package_version"
        case repository
        case license
        case licenses
    }
}

struct LicenseBundle: Codable {
    let rootName: String
    let thirdPartyLibraries: [LicenseEntry]

    enum CodingKeys: String, CodingKey {
        case rootName = "root_name"
        case thirdPartyLibraries = "third_party_libraries"
    }

    static func load() -> [LicenseEntry] {
        guard let url = Bundle.main.url(forResource: "licenses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bundle = try? JSONDecoder().decode(LicenseBundle.self, from: data)
        else {
            return []
        }

        let excludedPackages: Set<String> = [
            // Windows-only
            "schannel", "anstyle-wincon", "once_cell_polyfill",
            // WASI-only
            "wasi",
            // Optional features not activated on Apple
            "openssl-probe", "aho-corasick", "valuable",
            // Build-time codegen (uniffi toolchain)
            "uniffi_bindgen", "uniffi_build", "uniffi_testing", "uniffi_udl",
            "askama", "askama_derive", "askama_escape", "askama_parser",
            "weedle2", "goblin", "scroll", "scroll_derive", "plain",
            "cargo_metadata", "cargo-platform", "camino",
            "glob", "fs-err", "toml", "basic-toml",
            "textwrap", "smawk",
            "mime", "mime_guess", "siphasher", "unicase",
            "bincode", "static_assertions",
            // Build-time CLI tooling
            "clap", "clap_builder", "clap_derive", "clap_lex",
            "anstream", "anstyle", "anstyle-parse", "anstyle-query",
            "colorchoice", "is_terminal_polyfill", "strsim", "utf8parse",
            // Proc-macro dependencies (compile-time only)
            "proc-macro2", "quote", "syn", "unicode-ident", "heck", "paste",
        ]

        return bundle.thirdPartyLibraries
            .filter { !$0.packageName.hasPrefix("windows") && !excludedPackages.contains($0.packageName) }
            .sorted { $0.packageName.localizedCaseInsensitiveCompare($1.packageName) == .orderedAscending }
    }
}
