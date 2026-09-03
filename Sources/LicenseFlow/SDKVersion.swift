import Foundation

/// Canonical version marker for the LicenseFlow Swift SDK.
///
/// This is the single source of truth used by CI
/// (`scripts/verify-sdk-version.sh swift`) to assert that a pushed
/// `sdk-swift-v<semver>` tag matches the shipped package.
public enum LicenseFlowSDK {
    /// Semantic version of this package.
    public static let version = "2.2.0"

    /// User-Agent sent with every LicenseFlow API request.
    public static var userAgent: String {
        "licenseflow-swift/\(version)"
    }
}
