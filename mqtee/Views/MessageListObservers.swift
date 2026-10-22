import SwiftUI

// Standalone overlay that reads the node's received counters independently.
// Only this view re-renders when they change, not the parent List.
struct PendingCountOverlay: View {
    var selectedNode: TopicNode?
    var showAllDescendants: Bool
    /// The node's received counter captured when the list was last refreshed.
    var shownReceivedCount: Int
    var autoScroll: Bool
    var onShowNew: () -> Void
    var onAutoScroll: () -> Void

    private var pendingCount: Int {
        selectedNode?.pendingCount(since: shownReceivedCount, includeDescendants: showAllDescendants) ?? 0
    }

    var body: some View {
        if !autoScroll {
            HStack(spacing: 12) {
                if pendingCount > 0 {
                    Button {
                        onShowNew()
                    } label: {
                        Label("Show \(pendingCount) new", systemImage: "arrow.down.circle")
                    }
                }
                Button {
                    onAutoScroll()
                } label: {
                    Label("Auto scroll", systemImage: "arrow.down.to.line")
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// Zero-size view that isolates messageVersion observation from the List body.
// Only this view's body is invalidated on version bumps; the ForEach is untouched.
struct MessageVersionObserver: View {
    var session: SessionStore
    @Binding var autoScroll: Bool
    var onUpdate: () -> Void
    var onScroll: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: session.messageVersion) { _, _ in
                guard autoScroll else { return }
                onUpdate()
                Task { @MainActor in
                    onScroll()
                }
            }
    }
}
