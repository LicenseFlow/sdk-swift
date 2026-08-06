import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

public struct LicenseLease: Codable {
    public let licenseKey: String
    public let active: Bool
    public let fingerprint: String
    public let expiresAt: String
    public let entitlements: [String: AnyCodable]
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

public class LicenseFlowClient {
    private let apiKey: String
    private let baseUrl: String

    public init(apiKey: String, baseUrl: String = "https://api.licenseflow.dev/v1") {
        self.apiKey = apiKey
        self.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    public static func getDeviceFingerprint() -> String {
        #if os(iOS) || os(tvOS)
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        return "ios:\(idfv)"
        #else
        return "mac:\(Host.current().name ?? UUID().uuidString)"
        #endif
    }

    public func activate(licenseKey: String, fingerprint: String? = nil) async throws -> LicenseLease {
        let fp = fingerprint ?? Self.getDeviceFingerprint()
        let url = URL(string: "\(baseUrl)/licenses/activate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = ["key": licenseKey, "fingerprint": fp]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw NSError(domain: "LicenseFlow", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }

        return try JSONDecoder().decode(LicenseLease.self, from: data)
    }

    public func resolveForIdentity(authToken: String, organizationId: String, productId: String) async throws -> [String: Any] {
        let url = URL(string: "\(baseUrl)/entitlements/resolve-identity")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = ["organization_id": organizationId, "product_id": productId]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
