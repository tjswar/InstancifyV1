import Foundation
import CryptoKit
import Security

// Helper function to convert PEM key to DER format
func convertPEMToDER(pemKey: String) throws -> Data {
    // First, handle escaped newlines from JSON format
    let pemKey = pemKey
        .replacingOccurrences(of: "\\n", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Remove PEM headers and any whitespace/newlines
    let cleanKey = pemKey
        .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
        .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
        .components(separatedBy: .whitespacesAndNewlines)
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Decode base64 to get the raw key data
    guard let keyData = Data(base64Encoded: cleanKey, options: [.ignoreUnknownCharacters]) else {
        throw NSError(domain: "JWT", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid private key format - base64 decoding failed"])
    }
    
    print("[JWT] Original key length: \(pemKey.count)")
    print("[JWT] Cleaned key length: \(cleanKey.count)")
    print("[JWT] Key data length: \(keyData.count)")
    
    return keyData
}

// JWT encoding and signing
enum JWT {
    static func encode(header: [String: Any], claims: [String: Any], key: String) throws -> String {
        let headerJson = try JSONSerialization.data(withJSONObject: header)
        let claimsJson = try JSONSerialization.data(withJSONObject: claims)
        
        let headerBase64 = headerJson.base64URLEncodedString()
        let claimsBase64 = claimsJson.base64URLEncodedString()
        
        let signingInput = "\(headerBase64).\(claimsBase64)"
        
        let keyData = try convertPEMToDER(pemKey: key)
        
        // Create a dictionary with the key attributes
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        
        return try autoreleasepool {
            var error: Unmanaged<CFError>?
            
            guard let secKey = SecKeyCreateWithData(keyData as CFData,
                                                  attributes as CFDictionary,
                                                  &error) else {
                let underlyingError = error?.takeRetainedValue()
                print("[JWT] ❌ Failed to create SecKey: \(String(describing: underlyingError))")
                
                // Try to get more detailed error information
                if let err = underlyingError as? NSError {
                    print("[JWT] Error details - Domain: \(err.domain), Code: \(err.code)")
                    print("[JWT] Error description: \(err.localizedDescription)")
                    if let underlying = err.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("[JWT] Underlying error: \(underlying)")
                    }
                }
                
                // Try to extract the RSA key from PKCS#8 wrapper
                if let pkcs8Key = try? extractRSAKeyFromPKCS8(keyData) {
                    print("[JWT] Attempting with extracted RSA key...")
                    guard let extractedSecKey = SecKeyCreateWithData(pkcs8Key as CFData,
                                                                   attributes as CFDictionary,
                                                                   &error) else {
                        throw NSError(domain: "JWT",
                                    code: 2,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to create SecKey with extracted RSA key",
                                        NSUnderlyingErrorKey: error?.takeRetainedValue() as Any
                                    ])
                    }
                    
                    print("[JWT] ✅ Successfully created SecKey with extracted RSA key")
                    let signature = try sign(input: signingInput, with: extractedSecKey)
                    print("[JWT] ✅ Successfully signed JWT with extracted key")
                    return "\(signingInput).\(signature.base64URLEncodedString())"
                }
                
                throw NSError(domain: "JWT",
                            code: 2,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Failed to create SecKey",
                                NSUnderlyingErrorKey: underlyingError as Any
                            ])
            }
            
            print("[JWT] ✅ Successfully created SecKey")
            
            let signature = try sign(input: signingInput, with: secKey)
            print("[JWT] ✅ Successfully signed JWT")
            
            return "\(signingInput).\(signature.base64URLEncodedString())"
        }
    }
    
    private static func extractRSAKeyFromPKCS8(_ pkcs8Data: Data) throws -> Data {
        // Skip PKCS#8 header (usually 26 bytes for RSA 2048)
        // This is a simplified approach - in production you should properly parse ASN.1
        let headerLength = 26
        guard pkcs8Data.count > headerLength else {
            throw NSError(domain: "JWT", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid PKCS#8 data length"])
        }
        
        return pkcs8Data.subdata(in: headerLength..<pkcs8Data.count)
    }
    
    private static func sign(input: String, with key: SecKey) throws -> Data {
        guard let inputData = input.data(using: .utf8) else {
            throw NSError(domain: "JWT", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to encode input string"])
        }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key,
                                                  .rsaSignatureMessagePKCS1v15SHA256,
                                                  inputData as CFData,
                                                  &error) as Data? else {
            let underlyingError = error?.takeRetainedValue()
            throw NSError(domain: "JWT",
                        code: 5,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to create signature",
                            NSUnderlyingErrorKey: underlyingError as Any
                        ])
        }
        
        return signature
    }

    // Function to test JWT generation
    static func testJWTGeneration() {
        let privateKey = """
        -----BEGIN PRIVATE KEY-----
        MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDhZekkuMDZZtVw
        7k96vTCm016LdTICzA8LMXI6gvj7UGN4z473qDvugMnTbBUhEUxgtFFtScMJjbuw
        9A0Si0hgX48AW9RCPnefmUzIE/I2BM2Z9kQdEg2G4trxMdMrHyykIKwU+5OtTJFF
        Ps0nRhq+6g0mMaWGHMthzAMe8dWEDq+Fqg8izWyjqCwrqWYNkSzrqkcqOcNizHzJ
        57p3/2L8IQeb9QxuHoCGT2Ofo9FJ9jQ8JgT9sdh0Rnb7kybYRSEn0RzdNXCKmbXQ
        f3SgZQtqsUX9paQ3f1SmpOmpQ8Rs88y/H0xQh4UKER1m3ut3p+Jd8Nfoz8q9JueG
        SZmeucfnAgMBAAECggEASdHuwbAguRMM5KeoMDK2NG0VkecYMgJTCv9uwesTUHvL
        mE2iLUpUFpDniO7lHKdltGZaJMj7r61Tw2iqv2AOnEGvvBZXNjrvQr4af4zIzxhT
        nhEhzcOT2pGB02zWFFFpdXed5GFgxGlHSr5+wlYbfFt7Yv7vjzTvB2ChxQi/PThU
        hmIfTv10s03mZLmHBPy7GPAHTJjEA+ZNWxevg8zvPTfylKRq06MgdfGR/Okaqbw2
        naJi1fMo+BVY/4qeHpmD/6edq+bIkqplu3l7Cj7LnjMToV0kgDMoBI3uJREQE1rU
        QCi/GS9VAE3Tmfw0auqguQMehon/kmH1M02mBRFLgQKBgQD83wOvk43bliSNhyb5
        C6Js/wYiW5R5mexN3aoQgZlxhIa6Onpn7HuyUy0y3mbnCD81JzcVQRu90R8cwvwr
        oePw3oK6/aedbKeqAMPPdscyczn/YTZ40V9SiNT0tbQqA+RmbEH8S9Tol4cVWY0f
        /xxcX6aI1og3cPC55xHHeRwwPwKBgQDkL9+mcKiTPQAFeCRllTWkePXREpStuXx1
        g4KF2pRHaTRmnHU10tvpGBtSQ4nrp3D1CoVmt0RYhfoEYlay9+MEqt+KkuHVGnmg
        fosxF8CCRQ3qSo735/1erErR5e0MkfVzjQIm3wb66cZiB/qCM8MDCivgdwg98aTd
        gWoW0FJ+WQKBgCl9afxn6HGsC+lQ0JsyRn89xMLkZdMh5zzLbvjwWr3eccCikaz1
        h0I2FYdwKFAl8UEGYypQmX2mj0VH1NpP4LeHusl1jwfsaQIix/4FTh+/+jcluytN
        pydCnjZcjegK5XHMt3Lu+ksDeb2OCPLEB+I8K3XuRUFbfZPzDt68x1w/AoGAbxAG
        ESKgShnUmtThEjhPhaACNSKQDwZK13+M1c2PgjpocNESE4Jv2sIK+j05MeOrjPjz
        +QyWTWfYSq36eN1CN5FbgD0BghGCxWUSJnDjGAS4QyLK90qI/b1qJUN93zJjfzxQ
        oc7HvPRvxGMRwLGk5yPaO0R0VIH6tn04v6XhoPECgYADaqnP/P8NDSn3oxXudAuB
        8wvxRlGpdcNty4U0mwb2xIwBjf7PE1cgy3XNkAPUT0HFYMHKZcHNFPREkURnyR4v
        8MtpzwGxubDgXW4qgnBlgw/wAm+dGHwtMI+PRiaQ2aKWJ9QGF3P5tTXFYVVdD6bC
        qCHIHcj5GSY8O79GzVrtVQ==
        -----END PRIVATE KEY-----
        """

        let header = [
            "alg": "RS256",
            "typ": "JWT"
        ]

        let claims: [String: Any] = [
            "sub": "1234567890",
            "name": "John Doe",
            "iat": Int(Date().timeIntervalSince1970)
        ]

        do {
            let jwt = try JWT.encode(header: header, claims: claims, key: privateKey)
            print("Generated JWT: \(jwt)")
        } catch {
            print("Failed to generate JWT: \(error)")
        }
    }
}

// Extension for base64 URL encoding
extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
