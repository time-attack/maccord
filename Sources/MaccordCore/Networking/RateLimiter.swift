import Foundation

/// A simple, correct per-bucket rate limiter.
///
/// Discord scopes most limits to a `(X-RateLimit-Bucket, major-param)` pair. We
/// track each bucket's remaining-request count and reset time, and additionally
/// support a global pause that blocks every bucket (used on a global 429).
///
/// The limiter never mutates shared `JSONDecoder`/`URLSession` state — it only
/// holds `Date`/`Int` bookkeeping — so the actor's serialization is enough.
public actor RateLimiter {
    private struct BucketState {
        var remaining: Int
        var resetAt: Date
    }

    private var buckets: [String: BucketState] = [:]

    /// When non-nil and in the future, all sends wait until this instant.
    private var globalResumeAt: Date?

    public init() {}

    /// Call before sending. Waits out any global pause, then waits for the given
    /// bucket if it has no remaining requests and hasn't reset yet.
    public func willSend(bucket: String) async {
        // Global pause first.
        if let resume = globalResumeAt {
            let wait = resume.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(nanoseconds: nanos(from: wait))
            }
            if let g = globalResumeAt, g <= Date() {
                globalResumeAt = nil
            }
        }

        // Per-bucket pause.
        if let state = buckets[bucket], state.remaining <= 0 {
            let wait = state.resetAt.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(nanoseconds: nanos(from: wait))
            }
            // After waiting, optimistically allow one request through; the next
            // `didReceive` will correct the counter from fresh headers.
            buckets[bucket] = BucketState(remaining: 1, resetAt: Date())
        }
    }

    /// Update a bucket from response headers. Parses `X-RateLimit-Remaining` and
    /// `X-RateLimit-Reset-After` (a relative float in seconds). The opaque
    /// `X-RateLimit-Bucket` is read for diagnostics but we key on the caller's
    /// bucket string for stability across the request's lifetime.
    public func didReceive(headers: [AnyHashable: Any], bucket: String) {
        let remaining = intValue(headers, "X-RateLimit-Remaining")
        let resetAfter = doubleValue(headers, "X-RateLimit-Reset-After")

        // Honor a global flag if Discord marks one in non-429 traffic.
        if let scope = stringValue(headers, "X-RateLimit-Scope"), scope == "global",
           let after = resetAfter {
            globalPause(retryAfter: after)
        }

        guard let remaining else { return }
        let reset: Date
        if let resetAfter {
            reset = Date().addingTimeInterval(resetAfter)
        } else if let resetEpoch = doubleValue(headers, "X-RateLimit-Reset") {
            reset = Date(timeIntervalSince1970: resetEpoch)
        } else {
            reset = Date()
        }
        buckets[bucket] = BucketState(remaining: remaining, resetAt: reset)
    }

    /// Mark a bucket as exhausted for `retryAfter` seconds (used on a 429 that is
    /// not global, so future sends to this bucket wait).
    public func penalize(bucket: String, retryAfter: Double) {
        buckets[bucket] = BucketState(
            remaining: 0,
            resetAt: Date().addingTimeInterval(retryAfter)
        )
    }

    /// Pause every bucket for `retryAfter` seconds (global 429).
    public func globalPause(retryAfter: Double) {
        let resume = Date().addingTimeInterval(retryAfter)
        if let existing = globalResumeAt {
            globalResumeAt = max(existing, resume)
        } else {
            globalResumeAt = resume
        }
    }

    // MARK: - Helpers

    private func nanos(from seconds: Double) -> UInt64 {
        let clamped = max(0, seconds)
        // Guard against overflow for absurd values.
        let capped = min(clamped, 60 * 60)
        return UInt64(capped * 1_000_000_000)
    }

    private func stringValue(_ headers: [AnyHashable: Any], _ key: String) -> String? {
        if let v = headers[key] as? String { return v }
        // Header lookups are case-insensitive on the wire; fall back to a scan.
        for (k, value) in headers {
            if let ks = k as? String, ks.caseInsensitiveCompare(key) == .orderedSame {
                return value as? String
            }
        }
        return nil
    }

    private func intValue(_ headers: [AnyHashable: Any], _ key: String) -> Int? {
        guard let s = stringValue(headers, key) else { return nil }
        return Int(s) ?? Double(s).map { Int($0) }
    }

    private func doubleValue(_ headers: [AnyHashable: Any], _ key: String) -> Double? {
        guard let s = stringValue(headers, key) else { return nil }
        return Double(s)
    }
}
