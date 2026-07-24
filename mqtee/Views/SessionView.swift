import SwiftUI

struct SessionView: View {
    @Bindable var session: SessionStore
    var folder: ConnectionFolder?
    var onBack: (() -> Void)? = nil
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @State private var showPublishPanel: Bool = true
    #else
    @State private var showPublishPanel: Bool = false
    #endif
    @State private var showStatusPopover: Bool = false
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            mainContent

            LogStatusBarView(logStore: LogStore.shared, connectionId: session.connection.id) {
                openWindow(
                    id: "event-log",
                    value: EventLogWindowValue(
                        connectionId: session.connection.id,
                        connectionName: session.connection.name
                    )
                )
            }
        }
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItem(placement: .principal) {
                principalToolbarContent
            }
            ToolbarItem(placement: .primaryAction) {
                if !showPublishPanel {
                    Button {
                        session.showPublishPopover.toggle()
                    } label: {
                        Label("Publish Message", systemImage: "paperplane")
                    }
                    .popover(isPresented: Bindable(session).showPublishPopover, arrowEdge: .bottom) {
                        PublishPanelContent(session: session, isPinned: false) {
                            showPublishPanel = true
                            session.showPublishPopover = false
                        }
                        .frame(width: 500, height: 380)
                    }
                }
            }
        }
        .focusedSceneValue(\.showPublishPanel, $showPublishPanel)
        .onChange(of: session.showPublishPopover) { _, newValue in
            if newValue && showPublishPanel {
                session.showPublishPopover = false
            }
        }
        #else
        NavigationStack {
            VStack(spacing: 0) {
                mainContent

                LogStatusBarView(logStore: LogStore.shared, connectionId: session.connection.id) {
                    session.showLogSheet = true
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onBack {
                    ToolbarItem(placement: .navigation) {
                        Button(action: onBack) {
                            Label("Disconnect", systemImage: "eject")
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    principalToolbarContent
                }
                ToolbarItem(placement: .primaryAction) {
                    if horizontalSizeClass == .regular && !showPublishPanel {
                        Button {
                            session.showPublishPopover.toggle()
                        } label: {
                            Label("Publish Message", systemImage: "paperplane")
                        }
                        .popover(isPresented: Bindable(session).showPublishPopover) {
                            PublishPanelContent(session: session, isPinned: false) {
                                showPublishPanel = true
                                session.showPublishPopover = false
                            }
                            .frame(width: 500, height: 380)
                        }
                    } else if horizontalSizeClass == .compact {
                        Button {
                            session.showPublishPopover = true
                        } label: {
                            Label("Publish", systemImage: "paperplane")
                        }
                    }
                }
            }
            .sheet(isPresented: horizontalSizeClass == .compact ? Bindable(session).showPublishPopover : .constant(false)) {
                NavigationStack {
                    PublishPanelContent(session: session)
                        .navigationTitle("Publish Message")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { session.showPublishPopover = false }
                            }
                        }
                }
            }
            .sheet(isPresented: Bindable(session).showLogSheet) {
                NavigationStack {
                    LogView(logStore: LogStore.shared, connectionId: session.connection.id)
                        .navigationTitle("Event Log")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { session.showLogSheet = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showStatusPopover) {
                ConnectionStatusSheet(session: session, folder: folder)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: session.showPublishPopover) { _, newValue in
                if newValue && showPublishPanel {
                    session.showPublishPopover = false
                }
            }
        }
        #endif
    }

    private var mainContent: some View {
        TreeView(session: session, folder: folder, showPublishPanel: $showPublishPanel)
    }

    private var principalToolbarContent: some View {
        SessionToolbarContent(session: session, folder: folder, showStatusPopover: $showStatusPopover)
    }
}

#Preview("Session View") {
    SessionView(
        session: SessionStore.preview(),
        folder: ConnectionFolder(name: "Production", color: .green)
    )
    .frame(width: 1000, height: 700)
}
