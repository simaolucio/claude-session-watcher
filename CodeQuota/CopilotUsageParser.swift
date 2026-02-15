import Foundation

// MARK: - Copilot Usage Parser

/// Extracts Copilot usage parsing logic into a standalone, testable struct.
/// All methods are pure functions with no side effects.
struct CopilotUsageParser {
    
    enum ParseError: Error, Equatable {
        case invalidJSON
    }
    
    /// Parse raw JSON data into a `CopilotUsage` value.
    static func parseResponse(_ data: Data) -> Result<CopilotUsage, ParseError> {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.invalidJSON)
        }
        
        var totalUsed = 0
        var totalDiscount = 0
        var byModel: [(String, Int)] = []
        
        let items = (json["usageItems"] as? [[String: Any]])
            ?? (json["usage_items"] as? [[String: Any]])
            ?? []
        
        for item in items {
            let model = item["model"] as? String ?? "Unknown"
            
            let gross = intFromAny(item["grossQuantity"] ?? item["gross_quantity"])
            let discount = intFromAny(item["discountQuantity"] ?? item["discount_quantity"])
            
            totalUsed += gross
            totalDiscount += discount
            if gross > 0 {
                byModel.append((model, gross))
            }
        }
        
        let limit: Int
        if totalDiscount > 0 {
            limit = inferPlanLimit(fromDiscount: totalDiscount)
        } else {
            limit = 300 // Default Copilot Pro
        }
        
        let percent = limit > 0 ? min(Double(totalUsed) / Double(limit) * 100, 100) : 0
        
        byModel.sort { $0.1 > $1.1 }
        
        let usage = CopilotUsage(
            premiumRequestsUsed: totalUsed,
            premiumRequestsLimit: limit,
            percent: percent,
            byModel: byModel
        )
        
        return .success(usage)
    }
    
    // MARK: - Utilities
    
    /// Extract an Int from a JSON value that may be Int, Double, or String.
    static func intFromAny(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String, let i = Int(s) { return i }
        return 0
    }
    
    /// Infer the plan limit from the total discount (included allowance).
    static func inferPlanLimit(fromDiscount discount: Int) -> Int {
        let tiers = [50, 300, 1500]
        for tier in tiers {
            if discount <= tier { return tier }
        }
        return discount
    }
}
