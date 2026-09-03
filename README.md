# LicenseFlow Swift SDK (iOS / macOS)

Official Swift SDK for LicenseFlow — hardware-bound licensing, identity-based
entitlement resolution, floating seat leases and offline lease management for
iOS, macOS, tvOS and watchOS.

Current version: **2.2.0** · Platforms: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+

## Installation

### Swift Package Manager (Xcode)

`File → Add Package Dependencies…` and enter:

```
https://github.com/LicenseFlow/sdk-swift.git
```

Select version **2.2.0** (or "Up to Next Major").

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/LicenseFlow/sdk-swift.git", from: "2.2.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "LicenseFlow", package: "sdk-swift")
    ])
]
```

## Usage

```swift
import LicenseFlow

let client = LicenseFlowClient(apiKey: "lf_live_...")

// Hardware / IDFV-bound activation
Task {
    do {
        let lease = try await client.activate(licenseKey: "XXXX-XXXX-XXXX-XXXX")
        print("Active: \(lease.active), expires: \(lease.expiresAt)")
    } catch {
        print("Activation error: \(error)")
    }
}
```

### Offline entitlement cache

```swift
let cache = EntitlementCache(
    ttlSeconds: 300,
    offlineGraceHours: 72,
    strategy: .staleWhileRevalidate
)

switch cache.getStrategy("org:acme") {
case "use_cache":            break                       // serve locally
case "use_cache_revalidate": Task { /* refresh in bg */ } // serve + refresh
default:                     break                       // hit the network
}
```

### Diagnostics

```swift
print(LicenseFlowSDK.version)    // "2.2.0"
print(LicenseFlowSDK.userAgent)  // "licenseflow-swift/2.2.0"
```

## Development

```bash
swift build
swift test
```

## Releasing

Tag `sdk-swift-v<semver>` from `main`. CI verifies the tag against
`Sources/LicenseFlow/SDKVersion.swift`, publishes the GitHub release with build
provenance, and warms the Swift Package Index. See
[`sdk/PUBLISHING_GUIDE.md`](../PUBLISHING_GUIDE.md).

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).
