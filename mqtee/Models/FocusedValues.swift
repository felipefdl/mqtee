import SwiftUI

extension FocusedValues {
    @Entry var selectedConnection: Connection?
    @Entry var activeSession: SessionStore?
    @Entry var sidebarMode: Binding<SidebarMode>?
    @Entry var editConnection: ((Connection) -> Void)?
    @Entry var deleteConnection: ((Connection) -> Void)?
    @Entry var duplicateConnection: ((Connection) -> Void)?
    @Entry var connectToConnection: ((Connection) -> Void)?
    @Entry var selectedMessage: MQTTMessage?
    @Entry var selectedTopicNode: TopicNode?
    @Entry var importConnections: (() -> Void)?
    @Entry var exportConnections: (() -> Void)?
    @Entry var showPublishPanel: Binding<Bool>?
    @Entry var resetAllData: (() -> Void)?
    #if DEBUG
    @Entry var resetAndAddSampleBrokers: (() -> Void)?
    #endif
}
