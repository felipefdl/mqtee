import SwiftUI

/// Context menu for a message row: publish to its topic, or copy it in a chosen format.
struct MessageContextMenu: View {
    let message: MQTTMessage
    let session: SessionStore

    var body: some View {
        Button("Publish to this topic", systemImage: "paperplane") {
            session.preparePublishFromContext(topic: message.topic, payload: message.payloadString)
        }

        Divider()

        Button("Copy Message", systemImage: "doc.on.doc") {
            MessageExportService.copyToClipboard(MessageExportService.formatAsMarkdown(message))
        }

        Menu("Copy Message As...") {
            Button("Markdown") {
                MessageExportService.copyToClipboard(MessageExportService.formatAsMarkdown(message))
            }
            Button("JSON") {
                MessageExportService.copyToClipboard(MessageExportService.formatAsJSON(message))
            }
            Button("CSV") {
                MessageExportService.copyToClipboard(MessageExportService.formatMessagesAsCSV([message]))
            }
        }

        Button("Copy Payload Only", systemImage: "text.document") {
            MessageExportService.copyToClipboard(message.payloadString)
        }
    }
}
