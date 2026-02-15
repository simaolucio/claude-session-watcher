import Foundation
import CryptoKit
import Security

// MARK: - PKCE Helper

/// Extracts PKCE (Proof Key for Code Exchange) logic into a standalone, testable struct.
struct PKCEHelper {
    
    /// Generate cryptographically random bytes.
    static func generateRandomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
    
    /// Base64 URL encode data (RFC 4648 Section 5).
    /// Replaces `+` with `-`, `/` with `_`, and removes `=` padding.
    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Generate a PKCE verifier and S256 challenge pair.
    static func generatePKCE() -> (verifier: String, challenge: String) {
        let verifier = base64URLEncode(generateRandomBytes(32))
        let challengeData = SHA256.hash(data: Data(verifier.utf8))
        let challenge = base64URLEncode(Data(challengeData))
        return (verifier, challenge)
    }
    
    /// Compute the S256 challenge for a given verifier.
    /// Useful for deterministic testing.
    static func computeChallenge(for verifier: String) -> String {
        let challengeData = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(challengeData))
    }
}
