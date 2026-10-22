import Testing
import Foundation
@testable import MQTee

@Suite("JSONPrettyPrinter")
struct JSONPrettyPrinterTests {

    @Test("Preserves key order")
    func preservesKeyOrder() {
        let input = #"{"b":2,"a":1}"#
        let result = JSONPrettyPrinter.prettyPrint(input)!
        let bIndex = result.range(of: "\"b\"")!.lowerBound
        let aIndex = result.range(of: "\"a\"")!.lowerBound
        #expect(bIndex < aIndex)
    }

    @Test("Indents nested objects")
    func indentsNestedObjects() {
        let input = #"{"outer":{"inner":1}}"#
        let result = JSONPrettyPrinter.prettyPrint(input)!
        let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 5)
        #expect(lines[0] == "{")
        #expect(lines[1] == "    \"outer\": {")
        #expect(lines[2] == "        \"inner\": 1")
        #expect(lines[3] == "    }")
        #expect(lines[4] == "}")
    }

    @Test("Handles escaped strings")
    func handlesEscapedStrings() {
        let input = #"{"key":"val\"ue"}"#
        let result = JSONPrettyPrinter.prettyPrint(input)!
        #expect(result.contains(#"val\"ue"#))
    }

    @Test("Preserves number tokens verbatim")
    func preservesNumberTokens() {
        let input = #"{"n":1.5e10,"m":-0.0,"k":1E+2}"#
        let result = JSONPrettyPrinter.prettyPrint(input)!
        #expect(result.contains(#""n": 1.5e10"#))
        #expect(result.contains(#""m": -0.0"#))
        #expect(result.contains(#""k": 1E+2"#))
    }

    @Test("Does not round big integers")
    func preservesBigIntegers() {
        let input = #"{"id":9007199254740993,"f":[12345678901234567890.12345678901234567890]}"#
        let result = JSONPrettyPrinter.prettyPrint(input)!
        #expect(result.contains("9007199254740993"))
        #expect(result.contains("12345678901234567890.12345678901234567890"))
    }

    @Test("Strings with braces and escaped quotes are copied verbatim")
    func stringsCopiedVerbatim() {
        let input = #"{"a":"x\"},{\"y","b":"\\","c":"\u00e9 [1,2]"}"#
        let result = JSONPrettyPrinter.prettyPrint(input)!
        let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 5)
        #expect(lines[1] == #"    "a": "x\"},{\"y","#)
        #expect(lines[2] == #"    "b": "\\","#)
        #expect(lines[3] == #"    "c": "\u00e9 [1,2]""#)
    }

    @Test("Rejects malformed numbers, trailing data and unterminated strings")
    func rejectsMalformed() {
        #expect(JSONPrettyPrinter.prettyPrint("[01]") == nil)
        #expect(JSONPrettyPrinter.prettyPrint("[1.]") == nil)
        #expect(JSONPrettyPrinter.prettyPrint("{} x") == nil)
        #expect(JSONPrettyPrinter.prettyPrint(#"{"a":"b"#) == nil)
        #expect(JSONPrettyPrinter.prettyPrint(#"{"a":1,}"#) == nil)
    }

    @Test("Handles empty object")
    func handlesEmptyObject() {
        let input = "{}"
        let result = JSONPrettyPrinter.prettyPrint(input)!
        #expect(result == "{}")
    }

    @Test("Handles empty array")
    func handlesEmptyArray() {
        let input = "[]"
        let result = JSONPrettyPrinter.prettyPrint(input)!
        #expect(result == "[]")
    }

    @Test("Returns nil for invalid JSON")
    func returnsNilForInvalidJSON() {
        #expect(JSONPrettyPrinter.prettyPrint("{invalid}") == nil)
        #expect(JSONPrettyPrinter.prettyPrint("") == nil)
        #expect(JSONPrettyPrinter.prettyPrint("not json") == nil)
    }

    @Test("Idempotent - prettifying already pretty JSON produces same output")
    func idempotent() {
        let input = #"{"z":1,"a":[2,3]}"#
        let first = JSONPrettyPrinter.prettyPrint(input)!
        let second = JSONPrettyPrinter.prettyPrint(first)!
        #expect(first == second)
    }

    @Test("Handles arrays with mixed types")
    func handlesArraysWithMixedTypes() {
        let input = #"[1,"two",true,null]"#
        let result = JSONPrettyPrinter.prettyPrint(input)!
        #expect(result.contains("1"))
        #expect(result.contains("\"two\""))
        #expect(result.contains("true"))
        #expect(result.contains("null"))
    }

    @Test("Handles strings containing braces")
    func handlesStringsContainingBraces() {
        let input = #"{"msg":"{not a real object}"}"#
        let result = JSONPrettyPrinter.prettyPrint(input)!
        #expect(result.contains(#""{not a real object}""#))
    }
}
