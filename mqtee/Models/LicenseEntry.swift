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
        licenses.map { Self.reflowed($0.text) }.joined(separator: "\n\n---\n\n")
    }

    /// License files are hard-wrapped at a fixed column, which re-wraps raggedly on narrow screens.
    /// Joins the lines of plain paragraphs; paragraphs with indentation or list markers keep their breaks.
    static func reflowed(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"(?m)^={24,}[ \t]*$"#, with: "========================", options: .regularExpression)
        let paragraphs = normalized.components(separatedBy: "\n\n")
        return paragraphs.map { paragraph in
            let lines = paragraph.components(separatedBy: "\n")
            guard lines.count > 1, lines.allSatisfy(isPlainLine) else { return paragraph }
            return lines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        }.joined(separator: "\n\n")
    }

    nonisolated private static func isPlainLine(_ line: String) -> Bool {
        guard let first = line.first, !first.isWhitespace else { return false }
        if "-*•+#>".contains(first) { return false }
        return line.range(of: #"^\(?([0-9]+|[A-Za-z])[.)]\s"#, options: .regularExpression) == nil
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
