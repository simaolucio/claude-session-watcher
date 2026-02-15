import XCTest
@testable import CodeQuota

final class PKCEHelperTests: XCTestCase {
    
    // MARK: - base64URLEncode
    
    func testBase64URLEncode_noForbiddenCharacters() {
        // Test with data that would produce +, /, and = in standard base64
        // Byte 0xFB produces '+' in base64, 0xFF produces '/'
        let data = Data([0xFB, 0xFF, 0xFE, 0x01])
        let encoded = PKCEHelper.base64URLEncode(data)
        
        XCTAssertFalse(encoded.contains("+"), "Should not contain '+'")
        XCTAssertFalse(encoded.contains("/"), "Should not contain '/'")
        XCTAssertFalse(encoded.contains("="), "Should not contain '='")
    }
    
    func testBase64URLEncode_replacesCorrectly() {
        // A known input that produces specific base64 output
        let data = Data([0x00])
        let encoded = PKCEHelper.base64URLEncode(data)
        // base64 of 0x00 is "AA==" -> base64url should be "AA"
        XCTAssertEqual(encoded, "AA")
    }
    
    func testBase64URLEncode_emptyData() {
        let data = Data()
        let encoded = PKCEHelper.base64URLEncode(data)
        XCTAssertEqual(encoded, "")
    }
    
    // MARK: - generateRandomBytes
    
    func testGenerateRandomBytes_correctLength() {
        let data = PKCEHelper.generateRandomBytes(32)
        XCTAssertEqual(data.count, 32)
    }
    
    func testGenerateRandomBytes_zeroLength() {
        let data = PKCEHelper.generateRandomBytes(0)
        XCTAssertEqual(data.count, 0)
    }
    
    func testGenerateRandomBytes_differentEachCall() {
        let a = PKCEHelper.generateRandomBytes(32)
        let b = PKCEHelper.generateRandomBytes(32)
        // Extremely unlikely to be equal with 32 random bytes
        XCTAssertNotEqual(a, b)
    }
    
    // MARK: - generatePKCE
    
    func testGeneratePKCE_producesNonEmptyPair() {
        let pkce = PKCEHelper.generatePKCE()
        XCTAssertFalse(pkce.verifier.isEmpty)
        XCTAssertFalse(pkce.challenge.isEmpty)
    }
    
    func testGeneratePKCE_verifierIsBase64URLSafe() {
        let pkce = PKCEHelper.generatePKCE()
        XCTAssertFalse(pkce.verifier.contains("+"))
        XCTAssertFalse(pkce.verifier.contains("/"))
        XCTAssertFalse(pkce.verifier.contains("="))
    }
    
    func testGeneratePKCE_challengeIsBase64URLSafe() {
        let pkce = PKCEHelper.generatePKCE()
        XCTAssertFalse(pkce.challenge.contains("+"))
        XCTAssertFalse(pkce.challenge.contains("/"))
        XCTAssertFalse(pkce.challenge.contains("="))
    }
    
    func testGeneratePKCE_challengeMatchesVerifier() {
        let pkce = PKCEHelper.generatePKCE()
        // Re-compute the challenge from the verifier
        let expected = PKCEHelper.computeChallenge(for: pkce.verifier)
        XCTAssertEqual(pkce.challenge, expected)
    }
    
    func testGeneratePKCE_differentEachCall() {
        let a = PKCEHelper.generatePKCE()
        let b = PKCEHelper.generatePKCE()
        XCTAssertNotEqual(a.verifier, b.verifier)
        XCTAssertNotEqual(a.challenge, b.challenge)
    }
    
    // MARK: - computeChallenge
    
    func testComputeChallenge_deterministic() {
        let verifier = "test-verifier-string"
        let c1 = PKCEHelper.computeChallenge(for: verifier)
        let c2 = PKCEHelper.computeChallenge(for: verifier)
        XCTAssertEqual(c1, c2)
    }
    
    func testComputeChallenge_differentVerifiers_differentChallenges() {
        let c1 = PKCEHelper.computeChallenge(for: "verifier-a")
        let c2 = PKCEHelper.computeChallenge(for: "verifier-b")
        XCTAssertNotEqual(c1, c2)
    }
}
