//
//  FaviconService.swift
//  mqtee
//

import Foundation

@MainActor
@Observable
final class FaviconService {
    static let shared = FaviconService()

    var loadedIcons: [UUID: PlatformImage] = [:]

    private let fileManager = FileManager.default

    private var iconsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let iconsDir = appSupport.appendingPathComponent("mqtee/icons", isDirectory: true)
        try? fileManager.createDirectory(at: iconsDir, withIntermediateDirectories: true)
        return iconsDir
    }

    private init() {}

    func extractDomain(from host: String) -> String? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.isEmpty || trimmed == "localhost" {
            return nil
        }

        // IPv6
        if trimmed.contains(":") {
            return nil
        }

        // IPv4
        let parts = trimmed.split(separator: ".")
        if parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return nil
        }

        // Take last 2 parts for root domain
        if parts.count >= 2 {
            return parts.suffix(2).joined(separator: ".")
        }

        return nil
    }

    func fetchFavicon(for connectionId: UUID, host: String) async {
        guard let domain = extractDomain(from: host) else { return }

        // Try apple-touch-icon first (typically 180x180, high quality)
        if let data = await downloadIcon(from: "https://\(domain)/apple-touch-icon.png") {
            saveAndCache(data: data, for: connectionId)
            return
        }

        // Fall back to DuckDuckGo icons (free, no auth, good quality)
        if let data = await downloadIcon(from: "https://icons.duckduckgo.com/ip3/\(domain).ico") {
            saveAndCache(data: data, for: connectionId)
            return
        }
    }

    func loadIcon(for connectionId: UUID) -> PlatformImage? {
        if let cached = loadedIcons[connectionId] {
            return cached
        }
        let url = iconFileURL(for: connectionId)
        guard fileManager.fileExists(atPath: url.path),
              let image = PlatformImage.fromURL(url) else { return nil }
        loadedIcons[connectionId] = image
        return image
    }

    func loadAllIcons(for connectionIds: [UUID]) {
        for id in connectionIds {
            _ = loadIcon(for: id)
        }
    }

    func deleteIcon(for connectionId: UUID) {
        let url = iconFileURL(for: connectionId)
        try? fileManager.removeItem(at: url)
        loadedIcons.removeValue(forKey: connectionId)
    }

    // MARK: - Delete All

    func deleteAllIcons() {
        loadedIcons.removeAll()
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let iconsDir = appSupport.appendingPathComponent("mqtee/icons", isDirectory: true)
        try? fileManager.removeItem(at: iconsDir)
    }

    // MARK: - Private

    private nonisolated func downloadIcon(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  data.count > 100 else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func saveAndCache(data: Data, for connectionId: UUID) {
        let iconPath = iconFileURL(for: connectionId)
        try? data.write(to: iconPath, options: .atomic)
        if let image = PlatformImage.fromData(data) {
            loadedIcons[connectionId] = image
        }
    }

    private func iconFileURL(for connectionId: UUID) -> URL {
        iconsDirectory.appendingPathComponent("\(connectionId.uuidString).png")
    }
}
