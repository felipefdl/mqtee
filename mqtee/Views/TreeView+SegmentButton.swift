import SwiftUI

struct SidebarSegmentBar: View {
    var session: SessionStore
    @Binding var sidebarMode: SidebarMode

    var body: some View {
        ViewThatFits(in: .horizontal) {
            buttons(iconOnly: false)
            buttons(iconOnly: true)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func buttons(iconOnly: Bool) -> some View {
        HStack(spacing: 6) {
            segmentButton(
                "Topics",
                systemImage: "list.bullet.indent",
                mode: .topics,
                badge: session.topicTree.activeNodeCount,
                iconOnly: iconOnly
            )
            segmentButton(
                "Subscriptions",
                systemImage: "antenna.radiowaves.left.and.right",
                mode: .subscriptions,
                badge: session.subscriptions.count,
                iconOnly: iconOnly
            )
        }
    }

    private func segmentButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        mode: SidebarMode,
        badge: Int,
        iconOnly: Bool
    ) -> some View {
        let isSelected = sidebarMode == mode
        return Button {
            withAnimation(BrandTheme.springSnappy) {
                sidebarMode = mode
            }
        } label: {
            Group {
                if iconOnly {
                    Label(title, systemImage: systemImage).labelStyle(.iconOnly)
                } else {
                    Label(title, systemImage: systemImage)
                }
            }
            .font(.subheadline)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                Capsule().fill(.thinMaterial)
            }
        }
        .foregroundStyle(isSelected ? .primary : .secondary)
        .countBadge(badge)
        .geometryGroup()
        .animation(BrandTheme.springSnappy, value: badge)
    }
}

private extension View {
    @ViewBuilder
    func countBadge(_ count: Int) -> some View {
        if count > 0 {
            self.overlay(alignment: .topTrailing) {
                Text(verbatim: count >= 1000 ? "\(count / 1000)K+" : "\(count)")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.tint, in: .capsule)
                    .offset(x: 4, y: -4)
            }
        } else {
            self
        }
    }
}
