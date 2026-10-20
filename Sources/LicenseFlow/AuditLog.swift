import Foundation

/// Best-effort local text activity logging. On mobile use an app-private directory.
public final class LicenseFlowAuditLog: @unchecked Sendable {
    public var enabled: Bool
    public var directory: URL?
    private let lock = NSLock()

    public init(enabled: Bool? = nil, directory: URL? = nil) {
        self.enabled = enabled ?? ["1", "true", "yes"].contains(ProcessInfo.processInfo.environment["LICENSEFLOW_AUDIT_LOG", default: ""].lowercased())
        self.directory = directory
    }

    public static func mask(_ key: String?) -> String {
        guard let key = key, !key.isEmpty else { return "-" }
        return key.count <= 4 ? "****" : "****-" + key.suffix(4)
    }

    public func write(action: String, license: String?, status: Int, duration: Int, requestId: String?) {
        guard enabled else { return }
        lock.lock()
        defer { lock.unlock() }
        do {
            let manager = FileManager.default
            let now = Date()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let stamp = formatter.string(from: now)
            let override = ProcessInfo.processInfo.environment["LICENSEFLOW_AUDIT_DIR"]
            let dir = directory ?? override.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? manager.homeDirectoryForCurrentUser.appendingPathComponent(".licenseflow/logs", isDirectory: true)
            try manager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let stem = "licenseflow-audit-" + String(stamp.prefix(10))
            var file = dir.appendingPathComponent(stem + ".txt")
            var index = 0
            while let attrs = try? manager.attributesOfItem(atPath: file.path), let size = attrs[.size] as? NSNumber, size.intValue >= 10 * 1024 * 1024 {
                index += 1
                file = dir.appendingPathComponent(stem + ".\(index).txt")
            }
            let safe: (String) -> String = { value in String(value.map { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) ? $0 : "_" }.prefix(120)) }
            let line = "\(stamp) | actor=app | action=\(safe(action)) | license=\(Self.mask(license)) | result=\(status >= 200 && status < 400 ? "ok" : "error") | status=\(status == 0 ? "-" : String(status)) | duration_ms=\(duration) | request_id=\(safe(requestId ?? "-"))\n"
            if !manager.fileExists(atPath: file.path) { manager.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
            for old in try manager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) where old.lastPathComponent.hasPrefix("licenseflow-audit-") && old.pathExtension == "txt" {
                if let modified = try old.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, modified < now.addingTimeInterval(-14 * 86400) { try? manager.removeItem(at: old) }
            }
        } catch { /* Logging must never break the host application. */ }
    }
}