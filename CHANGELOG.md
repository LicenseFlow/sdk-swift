# Changelog — LicenseFlow Swift SDK

All notable changes to the iOS / macOS / tvOS / watchOS SDK.
This project follows [Semantic Versioning](https://semver.org/).

## [2.2.0] - 2026-09-03

### Features
- **Identity-based entitlement resolution** — `resolveForIdentity(...)` returns
  the effective entitlement set for a user/device identity without requiring a
  license key to be typed in by the end user.
- **Seat leases** — floating-seat checkout/checkin with automatic lease renewal
  and hardware fingerprint binding (IDFV on iOS, hardware UUID on macOS).
- **Offline entitlement cache** — `EntitlementCache` with TTL,
  `cacheFirst` / `staleWhileRevalidate` / `networkFirst` strategies and a
  configurable offline grace period (default 72h).
- **`LicenseFlowSDK.version` / `userAgent`** exposed for diagnostics and
  telemetry correlation.

### Documentation
- Swift Package Manager install instructions now match the published
  `LicenseFlow/sdk-swift` repository and `2.2.0` tag.

### Tests
- First unit-test target (`LicenseFlowTests`) covering cache TTL, offline grace,
  strategy selection and API response parsing.

## [2.1.0] - 2026-08-06

### Features
- Initial public Swift SDK: hardware-bound activation, license verification,
  lease management, update checks and artifact downloads.
