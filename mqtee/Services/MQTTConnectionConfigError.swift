import Foundation

/// Raised when a connection's numeric settings do not fit the MQTT wire-format ranges.
enum MQTTConnectionConfigError: LocalizedError, Equatable {
    case portOutOfRange(Int)
    case keepAliveOutOfRange(Int)
    case sessionExpiryOutOfRange(Int)
    case notANumber(String)

    var errorDescription: String? {
        switch self {
        case .portOutOfRange(let value):
            return String(localized: "Port \(value) is out of range. Use a value from 1 to 65535.", comment: "Connection validation error")
        case .keepAliveOutOfRange(let value):
            return String(localized: "Keep alive \(value) is out of range. Use a value from 0 to 65535 seconds.", comment: "Connection validation error")
        case .sessionExpiryOutOfRange(let value):
            return String(localized: "Session expiry \(value) is out of range. Use a value from 0 to 4294967295 seconds.", comment: "Connection validation error")
        case .notANumber(let value):
            return String(localized: "\"\(value)\" is not a whole number.", comment: "Connection validation error")
        }
    }

    /// Validated wire-format values for the numeric connection settings.
    struct Ranges: Equatable {
        let port: UInt16
        let keepAlive: UInt16
        let sessionExpiry: UInt32?
    }

    /// Converts without trapping; throws a descriptive error for any out-of-range value.
    static func validate(port: Int, keepAlive: Int, sessionExpiry: Int?) throws -> Ranges {
        guard (1...Int(UInt16.max)).contains(port) else { throw portOutOfRange(port) }
        guard let keepAliveValue = UInt16(exactly: keepAlive) else { throw keepAliveOutOfRange(keepAlive) }
        var expiryValue: UInt32?
        if let sessionExpiry {
            guard let value = UInt32(exactly: sessionExpiry) else { throw sessionExpiryOutOfRange(sessionExpiry) }
            expiryValue = value
        }
        return Ranges(port: UInt16(port), keepAlive: keepAliveValue, sessionExpiry: expiryValue)
    }

    /// Validates the editor's text fields. Empty fields fall back to the defaults the placeholders show
    /// (port 1883, keep alive 60, no session expiry); non-numeric text throws instead of silently defaulting.
    static func validate(port: String, keepAlive: String, sessionExpiry: String) throws -> Ranges {
        func number(_ text: String, default fallback: Int?) throws -> Int? {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return fallback }
            guard let value = Int(trimmed) else { throw notANumber(trimmed) }
            return value
        }
        return try validate(
            port: number(port, default: 1883) ?? 1883,
            keepAlive: number(keepAlive, default: 60) ?? 60,
            sessionExpiry: number(sessionExpiry, default: nil)
        )
    }
}
