import Foundation

// MARK: - MQTT Topic Matching

/// Checks whether an MQTT topic matches a subscription pattern with wildcards.
/// Supports `+` (single-level) and `#` (multi-level) wildcards per MQTT spec.
func mqttTopicMatchesPattern(topic: String, pattern: String) -> Bool {
    if pattern == topic { return true }
    if pattern == "#" { return true }

    let topicParts = topic.split(separator: "/", omittingEmptySubsequences: false)
    let patternParts = pattern.split(separator: "/", omittingEmptySubsequences: false)

    var topicIndex = 0
    var patternIndex = 0

    while patternIndex < patternParts.count {
        let patternPart = patternParts[patternIndex]

        if patternPart == "#" {
            return true
        }

        if topicIndex >= topicParts.count {
            return false
        }

        if patternPart == "+" {
            topicIndex += 1
            patternIndex += 1
        } else if patternPart == topicParts[topicIndex] {
            topicIndex += 1
            patternIndex += 1
        } else {
            return false
        }
    }

    return topicIndex == topicParts.count
}
