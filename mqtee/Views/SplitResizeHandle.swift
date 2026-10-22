import SwiftUI

#if !os(macOS)
/// Drag handle between the message list and the payload on iOS; drags adjust `splitRatio`
/// (list share of `totalHeight`), clamped to 15–85%.
struct SplitResizeHandle: View {
    @Binding var splitRatio: CGFloat
    let totalHeight: CGFloat
    @State private var dragStartRatio: CGFloat?

    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [.black.opacity(0.1), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 4)
                .allowsHitTesting(false)
            }
            .overlay {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 36, height: 4)
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartRatio ?? splitRatio
                        dragStartRatio = start
                        guard totalHeight > 0 else { return }
                        splitRatio = min(max(start + value.translation.height / totalHeight, 0.15), 0.85)
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
                    }
            )
    }
}
#endif
