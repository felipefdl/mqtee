import XCTest
@testable import MQTee

final class PayloadDetectionPerformanceTests: XCTestCase {

    // MARK: - JSON detection

    func testDetectJSON_Small() {
        let payload = BenchmarkHelpers.makeJSONString(approximateBytes: 100)
        let data = payload.data(using: .utf8)!

        measure {
            for _ in 0..<10_000 {
                _ = PayloadContentType.detect(from: data)
            }
        }
    }

    func testDetectJSON_Large() {
        let payload = BenchmarkHelpers.makeJSONString(approximateBytes: 50_000)
        let data = payload.data(using: .utf8)!

        measure {
            for _ in 0..<1_000 {
                _ = PayloadContentType.detect(from: data)
            }
        }
    }

    func testDetectInvalidJSON() {
        // Starts with { but is not valid JSON -- forces JSONSerialization parse failure
        let payload = "{this is not valid json at all, missing quotes and colons}"
        let data = payload.data(using: .utf8)!

        measure {
            for _ in 0..<10_000 {
                _ = PayloadContentType.detect(from: data)
            }
        }
    }

    // MARK: - Plain text detection

    func testDetectPlainText() {
        let payload = String(repeating: "Hello world, this is plain text. ", count: 10)
        let data = payload.data(using: .utf8)!

        measure {
            for _ in 0..<10_000 {
                _ = PayloadContentType.detect(from: data)
            }
        }
    }

    // MARK: - Binary detection

    func testDetectBinary() {
        let data = BenchmarkHelpers.makeBinaryData(size: 256)

        measure {
            for _ in 0..<10_000 {
                _ = PayloadContentType.detect(from: data)
            }
        }
    }

    // MARK: - Mixed batch (realistic distribution)

    func testDetectMixedBatch_1000() {
        // 60% JSON, 20% plain text, 10% XML, 10% binary
        var payloads: [Data] = []
        payloads.reserveCapacity(1000)

        for i in 0..<1000 {
            switch i % 10 {
            case 0..<6:
                let json = BenchmarkHelpers.makeJSONString(approximateBytes: 200)
                payloads.append(json.data(using: .utf8)!)
            case 6, 7:
                let text = "Sensor reading \(i): temperature=22.5C humidity=45%"
                payloads.append(text.data(using: .utf8)!)
            case 8:
                let xml = BenchmarkHelpers.makeXMLString(approximateBytes: 200)
                payloads.append(xml.data(using: .utf8)!)
            default:
                payloads.append(BenchmarkHelpers.makeBinaryData(size: 128))
            }
        }

        measure {
            for payload in payloads {
                _ = PayloadContentType.detect(from: payload)
            }
        }
    }
}
