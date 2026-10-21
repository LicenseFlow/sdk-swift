import XCTest
@testable import LicenseFlow

final class AuditLogTests: XCTestCase {
    func testMasking() {
        XCTAssertEqual(LicenseFlowAuditLog.mask("LF-SECRET-9A2C"), "****-9A2C")
        XCTAssertEqual(LicenseFlowAuditLog.mask("tiny"), "****")
    }
    func testDisabledAndEnabledFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let logger = LicenseFlowAuditLog(enabled: false, directory: directory)
        logger.write(action: "verify", license: "LF-SECRET-9A2C", status: 200, duration: 4, requestId: "request-123")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        logger.enabled = true
        logger.write(action: "verify", license: "LF-SECRET-9A2C", status: 200, duration: 4, requestId: "request-123")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        guard let file = files.first else { return XCTFail("No activity file") }
        let text = try String(contentsOf: file)
        XCTAssertFalse(text.contains("SECRET"))
        XCTAssertTrue(text.contains("request_id=request-123"))
    }
}