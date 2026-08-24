import Foundation

/// Thread-safe, TTL-based local entitlement cache for zero-network-request validation.
///
/// Strategies:
/// - `.cacheFirst` — Return cache if valid, else network.
/// - `.staleWhileRevalidate` — Return cache immediately, revalidate in background.
/// - `.networkFirst` — Always hit network, cache as fallback.
public final class EntitlementCache: @unchecked Sendable {

    // MARK: - Types

    public enum CacheStrategy {
        case cacheFirst
        case staleWhileRevalidate
        case networkFirst
    }

    public struct CachedEntry {
        public let data: [String: Any]
        public let cachedAt: Date
        public let expiresAt: Date
        /// "network", "cache", or "offline"
        public let source: String
    }

    // MARK: - Properties

    private var entries: [String: CachedEntry] = [:]
    private let lock = NSLock()
    private let ttl: TimeInterval
    private let gracePeriod: TimeInterval
    private let strategy: CacheStrategy

    // MARK: - Init

    public init(
        ttlSeconds: Int = 300,
        offlineGraceHours: Double = 72.0,
        strategy: CacheStrategy = .staleWhileRevalidate
    ) {
        self.ttl = TimeInterval(ttlSeconds)
        self.gracePeriod = offlineGraceHours * 3600
        self.strategy = strategy
    }

    // MARK: - Public API

    /// Get cached entitlements. Returns nil on miss or full expiry.
    public func get(_ key: String) -> CachedEntry? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = entries[key] else { return nil }

        let now = Date()

        // Within normal TTL
        if now < entry.expiresAt {
            return CachedEntry(data: entry.data, cachedAt: entry.cachedAt,
                               expiresAt: entry.expiresAt, source: "cache")
        }

        // Within offline grace period
        if now < entry.cachedAt.addingTimeInterval(gracePeriod) {
            return CachedEntry(data: entry.data, cachedAt: entry.cachedAt,
                               expiresAt: entry.expiresAt, source: "offline")
        }

        // Fully expired
        entries.removeValue(forKey: key)
        return nil
    }

    /// Store entitlement decision in cache.
    public func set(_ key: String, data: [String: Any]) {
        let now = Date()
        lock.lock()
        entries[key] = CachedEntry(
            data: data,
            cachedAt: now,
            expiresAt: now.addingTimeInterval(ttl),
            source: "network"
        )
        lock.unlock()
    }

    /// Remove a specific cached entry.
    public func invalidate(_ key: String) {
        lock.lock()
        entries.removeValue(forKey: key)
        lock.unlock()
    }

    /// Clear all cached entries.
    public func flush() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    /// Determine cache action: "use_cache", "use_cache_revalidate", or "use_network".
    public func getStrategy(_ key: String) -> String {
        guard let entry = get(key) else { return "use_network" }

        switch strategy {
        case .cacheFirst:
            return entry.source == "offline" ? "use_cache_revalidate" : "use_cache"
        case .staleWhileRevalidate:
            return entry.source == "cache" ? "use_cache" : "use_cache_revalidate"
        case .networkFirst:
            return "use_network"
        }
    }

    /// Number of cached entries.
    public var size: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }
}
