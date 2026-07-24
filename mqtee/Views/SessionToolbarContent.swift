import SwiftUI

struct SessionToolbarContent: View {
    @Bindable var session: SessionStore
    var folder: ConnectionFolder?

    @Binding var showStatusPopover: Bool
    @State private var isHoveringToolbar: Bool = false

    var body: some View {
        #if os(macOS)
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                if let folder {
                    Text(folder.name)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(folder.color.color)
                        )
                }
                Text(session.connection.name)
            }
            .font(.callout)

            Spacer()

            HStack(spacing: 6) {
                Text(session.statusLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Circle()
                    .fill(session.statusDotColor)
                    .frame(width: 8, height: 8)
            }
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .onContinuousHover { phase in
            isHoveringToolbar = switch phase {
            case .active: true
            case .ended: false
            }
        }
        .opacity(isHoveringToolbar ? 0.7 : 1.0)
        .animation(BrandTheme.easeQuick, value: isHoveringToolbar)
        .contentShape(Rectangle())
        .onTapGesture { showStatusPopover.toggle() }
        .popover(isPresented: $showStatusPopover) {
            ConnectionStatusPopover(session: session)
        }
        #else
        HStack(spacing: 6) {
            if let folder {
                Circle()
                    .fill(folder.color.color)
                    .frame(width: 8, height: 8)
            }
            Text(session.connection.name)
                .lineLimit(1)
                .font(.callout)
            Circle()
                .fill(session.statusDotColor)
                .frame(width: 8, height: 8)
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { showStatusPopover = true }
        #endif
    }
}
