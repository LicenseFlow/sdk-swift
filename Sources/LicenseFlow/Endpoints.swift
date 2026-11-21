import Foundation

/// Canonical REST paths (SDK v2.3+). The api.licenseflow.dev gateway serves
/// both these and the legacy paths indefinitely.
public enum LicenseFlowEndpoints {
    public static let canonical: [String: String] = [
        "verify-license": "/v1/licenses/verify",
        "activate-license": "/v1/licenses/activate",
        "deactivate-license": "/v1/licenses/deactivate",
        "checkout-license": "/v1/licenses/checkout",
        "checkin-license": "/v1/licenses/checkin",
        "lease-status": "/v1/licenses/lease-status",
        "generate-offline-license": "/v1/licenses/offline",
        "record-usage": "/v1/usage/record",
        "resolve-entitlements": "/v1/entitlements/resolve",
        "check-entitlement": "/v1/entitlements/check",
        "authorize": "/v1/access/authorize",
        "mcp-gateway": "/v1/mcp-gateway",
    ]

    /// Canonical absolute URL for a legacy endpoint, or nil when the base URL
    /// is not the LicenseFlow gateway.
    static func canonicalURL(baseUrl: String, endpoint: String) -> URL? {
        guard let base = URL(string: baseUrl), base.host == "api.licenseflow.dev",
              let scheme = base.scheme else { return nil }
        var name = endpoint
        if name.hasPrefix("/") { name.removeFirst() }
        if name.hasPrefix("functions/v1/") { name.removeFirst("functions/v1/".count) }
        guard let path = canonical[name] else { return nil }
        return URL(string: "\(scheme)://api.licenseflow.dev\(path)")
    }
}
