import XCTest
import SwiftUI
@testable import MQTee

final class JSONHighlighterPerformanceTests: XCTestCase {

    private let theme = SyntaxTheme(colorScheme: .dark)

    // MARK: - Small payloads

    func testHighlight_100Bytes() {
        let json = BenchmarkHelpers.makeJSONString(approximateBytes: 100)

        measure {
            for _ in 0..<1_000 {
                _ = JSONHighlighter.highlight(json, theme: theme)
            }
        }
    }

    // MARK: - Medium payloads

    func testHighlight_1KB() {
        let json = BenchmarkHelpers.makeJSONString(approximateBytes: 1_000)

        measure {
            for _ in 0..<500 {
                _ = JSONHighlighter.highlight(json, theme: theme)
            }
        }
    }

    // MARK: - Large payloads

    func testHighlight_10KB() {
        let json = BenchmarkHelpers.makeJSONString(approximateBytes: 10_000)

        measure {
            for _ in 0..<100 {
                _ = JSONHighlighter.highlight(json, theme: theme)
            }
        }
    }

    func testHighlight_50KB() {
        let json = BenchmarkHelpers.makeJSONString(approximateBytes: 50_000)

        measure {
            for _ in 0..<50 {
                _ = JSONHighlighter.highlight(json, theme: theme)
            }
        }
    }

    // MARK: - Guard path (over 100KB)

    func testHighlight_Over100KB() {
        let json = BenchmarkHelpers.makeJSONString(approximateBytes: 110_000)

        measure {
            for _ in 0..<100 {
                _ = JSONHighlighter.highlight(json, theme: theme)
            }
        }
    }
}
