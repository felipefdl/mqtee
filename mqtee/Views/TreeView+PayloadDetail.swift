import SwiftUI

extension TreeView {
    var payloadDetailPanel: some View {
        PayloadDisplayView(message: selectedMessage)
    }
}
