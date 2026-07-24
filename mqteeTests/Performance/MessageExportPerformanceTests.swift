import XCTest
@testable import MQTee

final class MessageExportPerformanceTests: XCTestCase {

    // MARK: - JSON export

    func testExportJSON_100() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 100, uniqueTopics: 20)

        measure {
            _ = MessageExportService.formatMessagesAsJSON(messages)
        }
    }

    func testExportJSON_1000() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 1000, uniqueTopics: 50)

        measure {
            _ = MessageExportService.formatMessagesAsJSON(messages)
        }
    }

    func testExportJSON_5000() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 5000, uniqueTopics: 100)

        measure {
            _ = MessageExportService.formatMessagesAsJSON(messages)
        }
    }

    // MARK: - CSV export

    func testExportCSV_100() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 100, uniqueTopics: 20)

        measure {
            _ = MessageExportService.formatMessagesAsCSV(messages)
        }
    }

    func testExportCSV_1000() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 1000, uniqueTopics: 50)

        measure {
            _ = MessageExportService.formatMessagesAsCSV(messages)
        }
    }

    func testExportCSV_5000() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 5000, uniqueTopics: 100)

        measure {
            _ = MessageExportService.formatMessagesAsCSV(messages)
        }
    }

    // MARK: - Markdown export

    func testExportMarkdown_100() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 100, uniqueTopics: 20)

        measure {
            _ = MessageExportService.formatMessages(messages, as: .markdown)
        }
    }

    func testExportMarkdown_1000() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 1000, uniqueTopics: 50)

        measure {
            _ = MessageExportService.formatMessages(messages, as: .markdown)
        }
    }

    // MARK: - JSON export with MQTT 5 properties

    func testExportJSON_WithV5Properties_500() {
        let messages = BenchmarkHelpers.makeBatchMessages(count: 500, uniqueTopics: 50, withV5: true)

        measure {
            _ = MessageExportService.formatMessagesAsJSON(messages)
        }
    }
}
