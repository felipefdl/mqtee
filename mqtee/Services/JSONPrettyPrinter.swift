import Foundation
import JavaScriptCore

struct JSONPrettyPrinter {
    private static let context: JSContext = {
        let ctx = JSContext()!
        return ctx
    }()

    static func prettyPrint(_ input: String, indent: Int = 4) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        context.setObject(trimmed, forKeyedSubscript: "jsonInput" as NSString)
        context.setObject(indent, forKeyedSubscript: "jsonIndent" as NSString)
        let result = context.evaluateScript("JSON.stringify(JSON.parse(jsonInput), null, jsonIndent)")

        guard let output = result?.toString(), output != "undefined" else { return nil }
        return output
    }
}
