import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - Error Types

public enum LicenseFlowError: Error, LocalizedError {
    case networkError(String)
    case rateLimitExceeded(String)
    case invalidLicense(String)
    case apiError(String, statusCode: Int)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Network Error: \(msg)"
        case .rateLimitExceeded(let msg): return "Rate Limit: \(msg)"
        case .invalidLicense(let msg): return "Invalid License: \(msg)"
        case .apiError(let msg, _): return "API Error: \(msg)"
        case .unknown(let msg): return msg
        }
    }
}

// MARK: - Data Models

public struct LicenseLease: Codable {
    public let licenseKey: String
    public let active: Bool
    public let fingerprint: String
    public let expiresAt: String
    public let entitlements: [String: AnyCodable]?
}

public struct CreditConsumptionResult {
    public let success: Bool
    public let balance: Int?
    public let consumed: Int?
    public let error: String?

    init(from dict: [String: Any]) {
        self.success = dict["success"] as? Bool ?? false
        self.balance = dict["balance"] as? Int ?? (dict["remaining_credits"] as? Int)
        self.consumed = dict["consumed"] as? Int ?? (dict["amount"] as? Int)
        self.error = dict["error"] as? String
    }
}

public struct CreditBalanceResult {
    public let balance: Int
    public let currency: String?

    init(from dict: [String: Any]) {
        self.balance = dict["balance"] as? Int ?? (dict["credits"] as? Int) ?? 0
        self.currency = dict["currency"] as? String ?? "credits"
    }
}

public struct VerificationResponse {
    public let valid: Bool
    public let status: String?
    public let licenseKey: String?
    public let productName: String?
    public let maxActivations: Int?
    public let currentActivations: Int?
    public let expiresAt: String?
    public let entitlements: [String: Any]?
    public let proof: String?
    public let error: String?

    init(from dict: [String: Any]) {
        self.valid = dict["valid"] as? Bool ?? false
        self.status = dict["status"] as? String
        self.licenseKey = dict["licenseKey"] as? String
        self.productName = dict["productName"] as? String
        self.maxActivations = dict["maxActivations"] as? Int
        self.currentActivations = dict["currentActivations"] as? Int
        self.expiresAt = dict["expiresAt"] as? String
        self.entitlements = dict["entitlements"] as? [String: Any]
        self.proof = dict["proof"] as? String
        self.error = dict["error"] as? String
    }
}

public struct LeaseResponse {
    public let success: Bool
    public let leaseKey: String?
    public let expiresAt: String?
    public let error: String?

    init(from dict: [String: Any]) {
        self.success = dict["success"] as? Bool ?? false
        self.leaseKey = dict["lease_key"] as? String ?? dict["leaseKey"] as? String
        self.expiresAt = dict["expiresAt"] as? String ?? dict["expires_at"] as? String
        self.error = dict["error"] as? String
    }
}

public struct UpdateInfo {
    public let id: String
    public let version: String
    public let changelog: String?
    public let publishedAt: String?

    init?(from dict: [String: Any], currentVersion: String) {
        guard let version = dict["version"] as? String, version != currentVersion else { return nil }
        self.id = dict["id"] as? String ?? ""
        self.version = version
        self.changelog = dict["changelog"] as? String
        self.publishedAt = dict["published_at"] as? String
    }
}

public struct ArtifactDownload {
    public let url: String
    public let filename: String?
    public let size: Int?

    init(from dict: [String: Any]) {
        self.url = dict["url"] as? String ?? dict["download_url"] as? String ?? ""
        self.filename = dict["filename"] as? String
        self.size = dict["size"] as? Int
    }
}

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) { value = b }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let s = try? container.decode(String.self) { value = s }
        else { value = "" }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let b = value as? Bool { try container.encode(b) }
        else if let i = value as? Int { try container.encode(i) }
        else if let d = value as? Double { try container.encode(d) }
        else if let s = value as? String { try container.encode(s) }
    }
}

// MARK: - Client

public class LicenseFlowClient {
    private let apiKey: String
    private let baseUrl: String
    private let cache = NSCache<NSString, NSDictionary>()
    private var heartbeatTask: Task<Void, Never>?

    public init(apiKey: String, baseUrl: String = "https://api.licenseflow.dev/v1") {
        self.apiKey = apiKey
        self.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        cache.countLimit = 100
    }

    // MARK: - Device Fingerprint

    public static func getDeviceFingerprint() -> String {
        #if os(iOS) || os(tvOS)
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        return "ios:\(idfv)"
        #else
        return "mac:\(Host.current().name ?? UUID().uuidString)"
        #endif
    }

    // MARK: - Activate

    /// Activate a license for a specific device
    public func activate(licenseKey: String, fingerprint: String? = nil) async throws -> LicenseLease {
        let fp = fingerprint ?? Self.getDeviceFingerprint()
        let body: [String: Any] = ["licenseKey": licenseKey, "deviceId": fp]
        let data = try await post(endpoint: "/activate-license", body: body)
        return try JSONDecoder().decode(LicenseLease.self, from: data)
    }

    // MARK: - Verify

    /// Verify the current status of a license with caching
    public func verify(licenseKey: String, deviceId: String? = nil, environmentId: String? = nil) async throws -> VerificationResponse {
        let did = deviceId ?? Self.getDeviceFingerprint()
        let cacheKey = "verify:\(licenseKey):\(did):\(environmentId ?? "default")" as NSString

        if let cached = cache.object(forKey: cacheKey) as? [String: Any] {
            return VerificationResponse(from: cached)
        }

        var body: [String: Any] = ["licenseKey": licenseKey, "deviceId": did]
        if let eid = environmentId { body["environmentId"] = eid }

        let data = try await post(endpoint: "/verify-license", body: body)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LicenseFlowError.unknown("Invalid response format")
        }

        let result = VerificationResponse(from: dict)
        if result.valid {
            cache.setObject(dict as NSDictionary, forKey: cacheKey)
        }

        return result
    }

    // MARK: - Deactivate

    /// Deactivate a license from a device
    public func deactivate(licenseKey: String, deviceId: String? = nil, environmentId: String? = nil) async throws -> [String: Any] {
        let did = deviceId ?? Self.getDeviceFingerprint()
        var body: [String: Any] = ["licenseKey": licenseKey, "deviceId": did]
        if let eid = environmentId { body["environmentId"] = eid }

        let data = try await post(endpoint: "/deactivate-license", body: body)
        cache.removeAllObjects()
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Entitlements

    /// Check if a verified license has a specific feature enabled
    public func hasFeature(_ verification: VerificationResponse, featureCode: String) -> Bool {
        guard verification.valid, let entitlements = verification.entitlements else { return false }
        guard let ent = entitlements[featureCode] else { return false }

        if let b = ent as? Bool { return b }
        if let dict = ent as? [String: Any] {
            return dict["enabled"] as? Bool ?? dict["value"] as? Bool ?? false
        }
        return false
    }

    /// Get entitlement value for a feature code
    public func getEntitlement(_ verification: VerificationResponse, featureCode: String) -> Any? {
        guard verification.valid, let entitlements = verification.entitlements else { return nil }
        return entitlements[featureCode]
    }

    // MARK: - Identity Resolution

    /// Identity-based (keyless) entitlement resolution
    public func resolveForIdentity(email: String, productId: String? = nil, environmentId: String? = nil) async throws -> [String: Any] {
        let cacheKey = "identity:\(email):\(productId ?? "all"):\(environmentId ?? "default")" as NSString

        if let cached = cache.object(forKey: cacheKey) as? [String: Any] {
            return cached
        }

        var body: [String: String] = ["email": email]
        if let pid = productId { body["productId"] = pid }
        if let eid = environmentId { body["environmentId"] = eid }

        let data = try await post(endpoint: "/resolve-entitlements", body: body)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        if dict["resolved"] as? Bool == true {
            cache.setObject(dict as NSDictionary, forKey: cacheKey)
        }

        return dict
    }

    // MARK: - Floating License Leases

    /// Acquire a temporary floating license lease
    public func checkoutLicense(
        licenseKey: String,
        durationSeconds: Int = 3600,
        requesterId: String? = nil,
        requesterType: String = "sdk",
        metadata: [String: Any]? = nil
    ) async throws -> LeaseResponse {
        var body: [String: Any] = [
            "license_key": licenseKey,
            "duration_seconds": durationSeconds,
            "requester_id": requesterId ?? Self.getDeviceFingerprint(),
            "requester_type": requesterType
        ]
        if let meta = metadata { body["metadata"] = meta }

        let data = try await post(endpoint: "/checkout-license", body: body)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return LeaseResponse(from: dict)
    }

    /// Release (check-in) a floating license lease
    public func checkinLicense(leaseKey: String) async throws -> [String: Any] {
        let body: [String: Any] = ["lease_key": leaseKey]
        let data = try await post(endpoint: "/checkin-license", body: body)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Get the status of a floating license lease
    public func getLeaseStatus(leaseKey: String) async throws -> LeaseResponse {
        let body: [String: Any] = ["lease_key": leaseKey]
        let data = try await post(endpoint: "/lease-status", body: body)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return LeaseResponse(from: dict)
    }

    // MARK: - Release Management

    /// Check for available software updates
    public func checkForUpdates(currentVersion: String, productId: String, channel: String = "stable") async throws -> UpdateInfo? {
        let params = "product_id=\(productId)&channel=\(channel)"
        let data = try await get(endpoint: "/release-management/latest?\(params)")
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return UpdateInfo(from: dict, currentVersion: currentVersion)
    }

    /// Download artifact with license verification
    public func downloadArtifact(
        licenseKey: String,
        releaseId: String? = nil,
        artifactId: String? = nil,
        platform: String? = nil,
        architecture: String? = nil
    ) async throws -> ArtifactDownload {
        var body: [String: Any] = ["licenseKey": licenseKey]
        if let rid = releaseId { body["release_id"] = rid }
        if let aid = artifactId { body["artifact_id"] = aid }
        if let p = platform { body["platform"] = p }
        if let a = architecture { body["architecture"] = a }

        let data = try await post(endpoint: "/artifact-download", body: body)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return ArtifactDownload(from: dict)
    }

    // MARK: - Usage Metering

    /// Record usage metrics for a license
    public func recordUsage(payload: [String: Any]) async throws -> [String: Any] {
        let data = try await post(endpoint: "/record-usage", body: payload)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Heartbeat

    /// Start periodic heartbeat to keep a license session alive
    public func startHeartbeat(licenseKey: String, intervalSeconds: TimeInterval = 60) {
        stopHeartbeat()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                do {
                    _ = try await self?.verify(licenseKey: licenseKey)
                } catch {
                    print("LicenseFlow heartbeat failed: \(error)")
                }
            }
        }
    }

    /// Stop the periodic heartbeat
    public func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    /// Clear the internal verification cache
    public func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - Usage & Credit Metering

    /// Consume credits from the organization's credit pool
    public func consumeCredits(
        amount: Int,
        description: String? = nil,
        productId: String? = nil,
        currency: String = "credits",
        referenceId: String? = nil,
        referenceType: String? = nil,
        metadata: [String: Any]? = nil
    ) async throws -> CreditConsumptionResult {
        var payload: [String: Any] = [
            "amount": amount,
            "currency": currency
        ]
        if let desc = description { payload["description"] = desc }
        if let pid = productId ?? self.productId { payload["product_id"] = pid }
        if let refId = referenceId { payload["reference_id"] = refId }
        if let refType = referenceType { payload["reference_type"] = refType }
        if let meta = metadata { payload["metadata"] = meta }

        let data = try await post(endpoint: "/functions/v1/consume-credits", body: payload)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return CreditConsumptionResult(from: dict)
    }

    /// Retrieve current credit balance for the organization or product
    public func getCreditsBalance(productId: String? = nil, currency: String? = nil) async throws -> CreditBalanceResult {
        var endpoint = "/functions/v1/get-credit-balance"
        var queryItems: [String] = []
        if let pid = productId ?? self.productId { queryItems.append("product_id=\(pid)") }
        if let curr = currency { queryItems.append("currency=\(curr)") }
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }

        let data = try await get(endpoint: endpoint)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return CreditBalanceResult(from: dict)
    }

    // MARK: - Offline Ed25519 License Verification

    /// Verify an offline .lic envelope containing an Ed25519 signature
    public func verifyOfflineLicense(licenseFileContent: String, publicKeyHex: String) throws -> [String: Any] {
        guard let jsonData = licenseFileContent.data(using: .utf8),
              let envelope = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let licenseObj = envelope["license"] as? [String: Any],
              let signatureBase64 = envelope["signature"] as? String,
              let signatureData = Data(base64Encoded: signatureBase64) else {
            throw LicenseFlowError.invalidLicense("Invalid offline license file format")
        }

        var keyData = Data()
        var hexStr = publicKeyHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("0x") { hexStr = String(hexStr.dropFirst(2)) }
        var index = hexStr.startIndex
        while index < hexStr.endIndex {
            let nextIndex = hexStr.index(index, offsetBy: 2, limitedBy: hexStr.endIndex) ?? hexStr.endIndex
            if let byte = UInt8(hexStr[index..<nextIndex], radix: 16) {
                keyData.append(byte)
            }
            index = nextIndex
        }

        guard keyData.count == 32 else {
            throw LicenseFlowError.invalidLicense("Public key must be 32 bytes hex")
        }

        #if canImport(CryptoKit)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            do {
                let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
                let messageData = try JSONSerialization.data(withJSONObject: licenseObj, options: [.sortedKeys])
                guard publicKey.isValidSignature(signatureData, for: messageData) else {
                    throw LicenseFlowError.invalidLicense("Invalid Ed25519 signature on offline license")
                }
            } catch {
                throw LicenseFlowError.invalidLicense("Signature verification failed: \(error.localizedDescription)")
            }
        }
        #endif

        if let validUntilStr = licenseObj["valid_until"] as? String ?? licenseObj["expires_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = formatter.date(from: validUntilStr) ?? ISO8601DateFormatter().date(from: validUntilStr)
            if let expiry = date, expiry < Date() {
                throw LicenseFlowError.invalidLicense("Offline license has expired")
            }
        }

        return licenseObj
    }

    // MARK: - HTTP Helpers

    private func post(endpoint: String, body: Any) async throws -> Data {
        let url = URL(string: "\(baseUrl)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        if let dict = body as? [String: Any] {
            request.httpBody = try JSONSerialization.data(withJSONObject: dict)
        } else {
            request.httpBody = try JSONEncoder().encode(body as! Encodable as! [String: String])
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(response, data: data)
        return data
    }

    private func get(endpoint: String) async throws -> Data {
        let url = URL(string: "\(baseUrl)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleHTTPResponse(response, data: data)
        return data
    }

    private func handleHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpRes = response as? HTTPURLResponse else {
            throw LicenseFlowError.unknown("Invalid response")
        }

        guard (200...299).contains(httpRes.statusCode) else {
            let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let message = body["message"] as? String ?? body["error"] as? String ?? "HTTP \(httpRes.statusCode)"

            switch httpRes.statusCode {
            case 429:
                throw LicenseFlowError.rateLimitExceeded(message)
            case 400, 404:
                throw LicenseFlowError.invalidLicense(message)
            default:
                throw LicenseFlowError.apiError(message, statusCode: httpRes.statusCode)
            }
        }
    }
}
