import Foundation

// MARK: - Claude Usage Parser

/// Extracts Claude usage parsing logic into a standalone, testable struct.
/// All methods are pure functions with no side effects.
struct ClaudeUsageParser {
    
    // MARK: - Date Formatters
    
    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    // MARK: - Public API
    
    enum ParseError: Error, Equatable {
        case invalidJSON
        case unrecognizedFormat(keys: [String])
    }
    
    /// Parse raw JSON data into a `ClaudeUsage` value.
    static func parseResponse(_ data: Data) -> Result<ClaudeUsage, ParseError> {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.invalidJSON)
        }
        
        // Parse each usage bucket — try many possible key names
        let fiveHour = parseBucket(json, key: "five_hour")
            ?? parseBucket(json, key: "fiveHour")
            ?? parseBucket(json, key: "5_hour")
            ?? parseBucket(json, key: "short_term")
            ?? parseBucket(json, key: "shortTerm")
        
        let dailyAll = parseBucket(json, key: "seven_day")
            ?? parseBucket(json, key: "seven_day_all")
            ?? parseBucket(json, key: "daily")
            ?? parseBucket(json, key: "sevenDayAll")
            ?? parseBucket(json, key: "7_day_all")
            ?? parseBucket(json, key: "long_term")
            ?? parseBucket(json, key: "longTerm")
            ?? parseBucket(json, key: "weekly")
        
        let dailySonnet = parseBucket(json, key: "seven_day_sonnet")
            ?? parseBucket(json, key: "daily_sonnet")
            ?? parseBucket(json, key: "sevenDaySonnet")
            ?? parseBucket(json, key: "7_day_sonnet")
            ?? parseBucket(json, key: "sonnet")
        
        // If none of the known keys matched, try dynamic parse
        if fiveHour == nil && dailyAll == nil && dailySonnet == nil {
            var buckets: [(String, UsageBucket)] = []
            for (key, value) in json {
                if let dict = value as? [String: Any],
                   let bucket = parseBucketFromDict(dict) {
                    buckets.append((key, bucket))
                }
            }
            
            if !buckets.isEmpty {
                let sorted = buckets.sorted { $0.0 < $1.0 }
                let usage = ClaudeUsage(
                    fiveHour: sorted.count > 0 ? sorted[0].1 : UsageBucket(percent: 0, resetAt: nil),
                    dailyAllModels: sorted.count > 1 ? sorted[1].1 : UsageBucket(percent: 0, resetAt: nil),
                    dailySonnet: sorted.count > 2 ? sorted[2].1 : UsageBucket(percent: 0, resetAt: nil)
                )
                return .success(usage)
            }
            
            return .failure(.unrecognizedFormat(keys: json.keys.sorted()))
        }
        
        let usage = ClaudeUsage(
            fiveHour: fiveHour ?? UsageBucket(percent: 0, resetAt: nil),
            dailyAllModels: dailyAll ?? UsageBucket(percent: 0, resetAt: nil),
            dailySonnet: dailySonnet ?? UsageBucket(percent: 0, resetAt: nil)
        )
        
        return .success(usage)
    }
    
    // MARK: - Bucket Parsing
    
    /// Try to parse a usage bucket from the JSON under a given key.
    /// Supports both nested object and flat key patterns.
    static func parseBucket(_ json: [String: Any], key: String) -> UsageBucket? {
        // Try as nested object
        if let bucket = json[key] as? [String: Any] {
            return parseBucketFromDict(bucket)
        }
        
        // Try as flat keys (e.g. "five_hour_utilization", "five_hour_reset_at")
        if let utilization = json["\(key)_utilization"] as? Double {
            let resetAt = parseDate(from: json, key: "\(key)_reset_at")
            return UsageBucket(percent: clamp0100(utilization), resetAt: resetAt)
        }
        
        return nil
    }
    
    /// Parse a usage bucket from a dictionary of values.
    static func parseBucketFromDict(_ dict: [String: Any]) -> UsageBucket? {
        let utilization = (dict["utilization"] as? Double)
            ?? (dict["usage"] as? Double)
            ?? (dict["percent"] as? Double).map { $0 / 100.0 }
            ?? (dict["value"] as? Double)
        
        guard let util = utilization else { return nil }
        
        let resetAt = parseDate(from: dict, key: "reset_at")
            ?? parseDate(from: dict, key: "resetAt")
            ?? parseDate(from: dict, key: "resets_at")
            ?? parseDate(from: dict, key: "reset")
            ?? parseDate(from: dict, key: "expires_at")
        
        return UsageBucket(percent: clamp0100(util), resetAt: resetAt)
    }
    
    // MARK: - Date Parsing
    
    /// Parse a date from a dictionary value, supporting ISO 8601 strings and Unix timestamps.
    static func parseDate(from dict: [String: Any], key: String) -> Date? {
        if let str = dict[key] as? String {
            return isoFormatter.date(from: str)
                ?? isoFormatterNoFrac.date(from: str)
        }
        if let ts = dict[key] as? TimeInterval {
            if ts > 1_000_000_000 {
                return Date(timeIntervalSince1970: ts)
            }
        }
        return nil
    }
    
    // MARK: - Utilities
    
    /// Clamp a value to the range [0, 100].
    static func clamp0100(_ v: Double) -> Double {
        min(max(v, 0), 100)
    }
}
