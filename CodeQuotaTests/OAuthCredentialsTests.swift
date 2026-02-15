import XCTest
@testable import CodeQuota

final class OAuthCredentialsTests: XCTestCase {
    
    // MARK: - isExpired
    
    func testIsExpired_pastDate_returnsTrue() {
        let creds = OAuthCredentials(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresAt: Date().addingTimeInterval(-60) // 1 minute ago
        )
        XCTAssertTrue(creds.isExpired)
    }
    
    func testIsExpired_futureDate_returnsFalse() {
        let creds = OAuthCredentials(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour from now
        )
        XCTAssertFalse(creds.isExpired)
    }
    
    func testIsExpired_exactlyNow_returnsTrue() {
        // Date() >= expiresAt when they're the same
        let now = Date()
        let creds = OAuthCredentials(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresAt: now
        )
        // By the time we check, Date() >= now is true
        XCTAssertTrue(creds.isExpired)
    }
    
    // MARK: - Codable
    
    func testCodable_roundTrip() throws {
        let original = OAuthCredentials(
            accessToken: "access-123",
            refreshToken: "refresh-456",
            expiresAt: Date(timeIntervalSince1970: 1700000000)
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OAuthCredentials.self, from: data)
        
        XCTAssertEqual(decoded.accessToken, original.accessToken)
        XCTAssertEqual(decoded.refreshToken, original.refreshToken)
        XCTAssertEqual(decoded.expiresAt, original.expiresAt)
    }
}
