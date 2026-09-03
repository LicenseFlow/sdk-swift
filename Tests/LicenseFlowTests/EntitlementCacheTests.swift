import XCTest
@testable import LicenseFlow

final class EntitlementCacheTests: XCTestCase {

    func testSetAndGetReturnsCachedEntry() {
        let cache = EntitlementCache(ttlSeconds: 300)
        cache.set("org:1", data: ["plan": "pro"])

        let entry = cache.get("org:1")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.source, "cache")
        XCTAssertEqual(entry?.data["plan"] as? String, "pro")
        XCTAssertEqual(cache.size, 1)
    }

    func testMissReturnsNil() {
        let cache = EntitlementCache()
        XCTAssertNil(cache.get("nope"))
    }

    func testExpiredEntryFallsBackToOfflineGrace() {
        // TTL already elapsed, but still inside the offline grace window.
        let cache = EntitlementCache(ttlSeconds: 0, offlineGraceHours: 72)
        cache.set("org:1", data: ["plan": "pro"])

        let entry = cache.get("org:1")
        XCTAssertEqual(entry?.source, "offline")
    }

    func testFullyExpiredEntryIsEvicted() {
        let cache = EntitlementCache(ttlSeconds: 0, offlineGraceHours: 0)
        cache.set("org:1", data: ["plan": "pro"])

        XCTAssertNil(cache.get("org:1"))
        XCTAssertEqual(cache.size, 0)
    }

    func testInvalidateAndFlush() {
        let cache = EntitlementCache()
        cache.set("a", data: [:])
        cache.set("b", data: [:])

        cache.invalidate("a")
        XCTAssertNil(cache.get("a"))
        XCTAssertNotNil(cache.get("b"))

        cache.flush()
        XCTAssertEqual(cache.size, 0)
    }

    func testStrategySelection() {
        let networkFirst = EntitlementCache(strategy: .networkFirst)
        networkFirst.set("k", data: [:])
        XCTAssertEqual(networkFirst.getStrategy("k"), "use_network")

        let swr = EntitlementCache(ttlSeconds: 300, strategy: .staleWhileRevalidate)
        swr.set("k", data: [:])
        XCTAssertEqual(swr.getStrategy("k"), "use_cache")

        let stale = EntitlementCache(ttlSeconds: 0, offlineGraceHours: 72, strategy: .cacheFirst)
        stale.set("k", data: [:])
        XCTAssertEqual(stale.getStrategy("k"), "use_cache_revalidate")

        let empty = EntitlementCache()
        XCTAssertEqual(empty.getStrategy("missing"), "use_network")
    }
}
