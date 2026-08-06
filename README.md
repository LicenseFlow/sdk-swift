# LicenseFlow Swift SDK (iOS / macOS)

Official Swift SDK for LicenseFlow — Hardware-bound licensing, keyless identity resolution, and offline lease management for iOS, macOS, tvOS, and watchOS.

## Installation

### Swift Package Manager (SPM)
In Xcode: `File → Add Package Dependencies...`
Enter repository URL: `https://github.com/licenseflow/licenseflow-swift`
Select version: `v2.1.0`

## Usage Example

```swift
import LicenseFlow

let client = LicenseFlowClient(apiKey: "lf_live_...")

// Hardware / IDFV Activation
Task {
    do {
        let lease = try await client.activate(licenseKey: "XXXX-XXXX-XXXX-XXXX")
        print("Active: \(lease.active)")
    } catch {
        print("Activation error: \(error)")
    }
}
```
