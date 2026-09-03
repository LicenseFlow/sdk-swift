import XCTest
@testable import LicenseFlow

final class ResponseParsingTests: XCTestCase {

    func testSDKVersionIsExposed() {
        XCTAssertEqual(LicenseFlowSDK.version, "2.2.0")
        XCTAssertEqual(LicenseFlowSDK.userAgent, "licenseflow-swift/2.2.0")
    }

    func testVerificationResponseParsesValidPayload() {
        let response = VerificationResponse(from: [
            "valid": true,
            "status": "active",
            "licenseKey": "AAAA-BBBB-CCCC-DDDD",
            "productName": "Acme Pro",
            "maxActivations": 5,
            "currentActivations": 2,
            "expiresAt": "2027-01-01T00:00:00Z",
            "entitlements": ["seats": 5],
        ])

        XCTAssertTrue(response.valid)
        XCTAssertEqual(response.status, "active")
        XCTAssertEqual(response.licenseKey, "AAAA-BBBB-CCCC-DDDD")
        XCTAssertEqual(response.maxActivations, 5)
        XCTAssertEqual(response.currentActivations, 2)
        XCTAssertEqual(response.entitlements?["seats"] as? Int, 5)
        XCTAssertNil(response.error)
    }

    func testVerificationResponseDefaultsToInvalid() {
        let response = VerificationResponse(from: ["error": "not_found"])
        XCTAssertFalse(response.valid)
        XCTAssertEqual(response.error, "not_found")
    }

    func testLeaseResponseAcceptsBothKeyCasings() {
        let snake = LeaseResponse(from: [
            "success": true,
            "lease_key": "lease_1",
            "expires_at": "2026-09-04T00:00:00Z",
        ])
        XCTAssertTrue(snake.success)
        XCTAssertEqual(snake.leaseKey, "lease_1")
        XCTAssertEqual(snake.expiresAt, "2026-09-04T00:00:00Z")

        let camel = LeaseResponse(from: [
            "success": true,
            "leaseKey": "lease_2",
            "expiresAt": "2026-09-05T00:00:00Z",
        ])
        XCTAssertEqual(camel.leaseKey, "lease_2")
        XCTAssertEqual(camel.expiresAt, "2026-09-05T00:00:00Z")
    }

    func testUpdateInfoIsNilWhenVersionMatchesCurrent() {
        XCTAssertNil(UpdateInfo(from: ["version": "2.2.0"], currentVersion: "2.2.0"))

        let update = UpdateInfo(from: ["id": "r1", "version": "2.3.0", "changelog": "New"],
                                currentVersion: "2.2.0")
        XCTAssertEqual(update?.version, "2.3.0")
        XCTAssertEqual(update?.changelog, "New")
    }

    func testArtifactDownloadFallsBackToDownloadUrl() {
        let artifact = ArtifactDownload(from: ["download_url": "https://cdn/x.zip", "size": 42])
        XCTAssertEqual(artifact.url, "https://cdn/x.zip")
        XCTAssertEqual(artifact.size, 42)
    }
}
