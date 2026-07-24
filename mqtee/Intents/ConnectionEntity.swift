//
//  ConnectionEntity.swift
//  mqtee
//

import AppIntents

struct ConnectionEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Connection"
    static var defaultQuery = ConnectionEntityQuery()

    var id: UUID
    var name: String
    var subtitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }

    init(from connection: Connection) {
        self.id = connection.id
        self.name = connection.name
        self.subtitle = "\(connection.host):\(connection.port)"
    }

    init(id: UUID, name: String, subtitle: String) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
    }
}
