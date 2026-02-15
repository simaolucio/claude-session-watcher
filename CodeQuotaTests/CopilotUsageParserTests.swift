import XCTest
@testable import CodeQuota

final class CopilotUsageParserTests: XCTestCase {
    
    // MARK: - Helpers
    
    private func jsonData(_ dict: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dict)
    }
    
    // MARK: - intFromAny
    
    func testIntFromAny_intValue() {
        XCTAssertEqual(CopilotUsageParser.intFromAny(42), 42)
    }
    
    func testIntFromAny_doubleValue() {
        XCTAssertEqual(CopilotUsageParser.intFromAny(42.7), 42)
    }
    
    func testIntFromAny_stringValue() {
        XCTAssertEqual(CopilotUsageParser.intFromAny("42"), 42)
    }
    
    func testIntFromAny_invalidString() {
        XCTAssertEqual(CopilotUsageParser.intFromAny("abc"), 0)
    }
    
    func testIntFromAny_nilValue() {
        XCTAssertEqual(CopilotUsageParser.intFromAny(nil), 0)
    }
    
    func testIntFromAny_boolValue() {
        // Bools should fall through to 0
        XCTAssertEqual(CopilotUsageParser.intFromAny(true), 0)
    }
    
    // MARK: - inferPlanLimit
    
    func testInferPlanLimit_belowFirstTier() {
        XCTAssertEqual(CopilotUsageParser.inferPlanLimit(fromDiscount: 30), 50)
    }
    
    func testInferPlanLimit_exactlyFirstTier() {
        XCTAssertEqual(CopilotUsageParser.inferPlanLimit(fromDiscount: 50), 50)
    }
    
    func testInferPlanLimit_betweenFirstAndSecond() {
        XCTAssertEqual(CopilotUsageParser.inferPlanLimit(fromDiscount: 200), 300)
    }
    
    func testInferPlanLimit_exactlySecondTier() {
        XCTAssertEqual(CopilotUsageParser.inferPlanLimit(fromDiscount: 300), 300)
    }
    
    func testInferPlanLimit_betweenSecondAndThird() {
        XCTAssertEqual(CopilotUsageParser.inferPlanLimit(fromDiscount: 1000), 1500)
    }
    
    func testInferPlanLimit_exactlyThirdTier() {
        XCTAssertEqual(CopilotUsageParser.inferPlanLimit(fromDiscount: 1500), 1500)
    }
    
    func testInferPlanLimit_exceedsAllTiers() {
        // When discount exceeds all known tiers, use the discount itself
        XCTAssertEqual(CopilotUsageParser.inferPlanLimit(fromDiscount: 5000), 5000)
    }
    
    // MARK: - parseResponse
    
    func testParseResponse_fullUsageItems() {
        let data = jsonData([
            "usageItems": [
                ["model": "gpt-4o", "grossQuantity": 100.0, "discountQuantity": 100.0],
                ["model": "claude-sonnet", "grossQuantity": 50.0, "discountQuantity": 50.0],
                ["model": "gpt-4o", "grossQuantity": 30.0, "discountQuantity": 30.0]
            ]
        ])
        
        let result = CopilotUsageParser.parseResponse(data)
        
        switch result {
        case .success(let usage):
            XCTAssertEqual(usage.premiumRequestsUsed, 180) // 100 + 50 + 30
            // Total discount = 180, nearest tier >= 180 is 300
            XCTAssertEqual(usage.premiumRequestsLimit, 300)
            XCTAssertEqual(usage.percent, 60.0, accuracy: 0.01) // 180/300 * 100
            // byModel should be sorted by count descending
            XCTAssertEqual(usage.byModel.count, 3)
            XCTAssertEqual(usage.byModel[0].0, "gpt-4o")
            XCTAssertEqual(usage.byModel[0].1, 100)
        case .failure:
            XCTFail("Expected success")
        }
    }
    
    func testParseResponse_snakeCaseKeys() {
        let data = jsonData([
            "usage_items": [
                ["model": "gpt-4o", "gross_quantity": 200, "discount_quantity": 200]
            ]
        ])
        
        let result = CopilotUsageParser.parseResponse(data)
        
        switch result {
        case .success(let usage):
            XCTAssertEqual(usage.premiumRequestsUsed, 200)
            XCTAssertEqual(usage.premiumRequestsLimit, 300)
        case .failure:
            XCTFail("Expected success")
        }
    }
    
    func testParseResponse_emptyUsageItems() {
        let data = jsonData(["usageItems": [] as [[String: Any]]])
        
        let result = CopilotUsageParser.parseResponse(data)
        
        switch result {
        case .success(let usage):
            XCTAssertEqual(usage.premiumRequestsUsed, 0)
            XCTAssertEqual(usage.premiumRequestsLimit, 300) // Default
            XCTAssertEqual(usage.percent, 0)
            XCTAssertTrue(usage.byModel.isEmpty)
        case .failure:
            XCTFail("Expected success")
        }
    }
    
    func testParseResponse_noUsageItemsKey() {
        // Response has no usageItems key at all — should still parse as empty
        let data = jsonData(["something": "else"])
        
        let result = CopilotUsageParser.parseResponse(data)
        
        switch result {
        case .success(let usage):
            XCTAssertEqual(usage.premiumRequestsUsed, 0)
            XCTAssertEqual(usage.premiumRequestsLimit, 300)
        case .failure:
            XCTFail("Expected success")
        }
    }
    
    func testParseResponse_invalidJSON() {
        let data = "not json".data(using: .utf8)!
        let result = CopilotUsageParser.parseResponse(data)
        
        switch result {
        case .success:
            XCTFail("Expected failure for invalid JSON")
        case .failure(let error):
            XCTAssertEqual(error, .invalidJSON)
        }
    }
    
    func testParseResponse_percentCappedAt100() {
        // Usage exceeds limit
        let data = jsonData([
            "usageItems": [
                ["model": "gpt-4o", "grossQuantity": 400.0, "discountQuantity": 40.0]
            ]
        ])
        
        let result = CopilotUsageParser.parseResponse(data)
        
        switch result {
        case .success(let usage):
            // Discount 40 -> tier 50, usage 400 -> 400/50*100 = 800% but capped at 100
            XCTAssertEqual(usage.premiumRequestsLimit, 50)
            XCTAssertEqual(usage.percent, 100)
        case .failure:
            XCTFail("Expected success")
        }
    }
    
    func testParseResponse_zeroGrossItems_excludedFromByModel() {
        let data = jsonData([
            "usageItems": [
                ["model": "gpt-4o", "grossQuantity": 100.0, "discountQuantity": 100.0],
                ["model": "unused-model", "grossQuantity": 0.0, "discountQuantity": 0.0]
            ]
        ])
        
        let result = CopilotUsageParser.parseResponse(data)
        
        switch result {
        case .success(let usage):
            XCTAssertEqual(usage.byModel.count, 1)
            XCTAssertEqual(usage.byModel[0].0, "gpt-4o")
        case .failure:
            XCTFail("Expected success")
        }
    }
    
    // MARK: - CopilotUsage.empty
    
    func testCopilotUsageEmpty() {
        let empty = CopilotUsage.empty
        XCTAssertEqual(empty.premiumRequestsUsed, 0)
        XCTAssertEqual(empty.premiumRequestsLimit, 0)
        XCTAssertEqual(empty.percent, 0)
        XCTAssertTrue(empty.byModel.isEmpty)
    }
}
