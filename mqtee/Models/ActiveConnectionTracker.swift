//
//  ActiveConnectionTracker.swift
//  mqtee
//

import SwiftUI

@MainActor
@Observable
final class ActiveConnectionTracker {
    static let shared = ActiveConnectionTracker()
    private(set) var activeConnectionIds: Set<UUID> = []

    private init() {}

    func claim(_ connectionId: UUID) -> Bool {
        guard !activeConnectionIds.contains(connectionId) else { return false }
        activeConnectionIds.insert(connectionId)
        return true
    }

    func release(_ connectionId: UUID) {
        activeConnectionIds.remove(connectionId)
    }

    func isActive(_ connectionId: UUID) -> Bool {
        activeConnectionIds.contains(connectionId)
    }
}
