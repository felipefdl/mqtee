import SwiftUI

// Standalone overlay that reads TopicNode.cachedTotalCount independently.
// Only this view re-renders when the count changes, not the parent List.
struct PendingCountOverlay: View {
    var selectedNode: TopicNode?
    var showAllDescendants: Bool
    var currentCount: Int
    var autoScroll: Bool
    var onShowNew: () -> Void
    var onAutoScroll: () -> Void

    private var pendingCount: Int {
        guard let selectedNode else { return 0 }
        let total = showAllDescendants ? selectedNode.totalMessageCount : selectedNode.messageCount
        return max(0, total - currentCount)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 8)
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
