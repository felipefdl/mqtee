//
//  ConnectionEntityQuery.swift
//  mqtee
//

import AppIntents
import Foundation

struct ConnectionEntityQuery: EntityQuery {
    func entities(for identifiers: [ConnectionEntity.ID]) async throws -> [ConnectionEntity] {
        let connections = Self.loadConnections()
        return connections
            .filter { identifiers.contains($0.id) }
            .map { ConnectionEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [ConnectionEntity] {
        Self.loadConnections().map { ConnectionEntity(from: $0) }
    }

    /// Loads connections from UserDefaults (same key as ConnectionStore) to avoid @MainActor dependency.
    static func loadConnections() -> [Connection] {
        guard let data = UserDefaults.standard.data(forKey: "connections") else {
            return []
        }
        return (try? JSONDecoder().decode([Connection].self, from: data)) ?? []
    }
}
