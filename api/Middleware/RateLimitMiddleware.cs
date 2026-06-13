using System.Collections.Concurrent;

namespace PomApi.Middleware;

/// <summary>
/// Sliding-window rate limiter: 100 requests per hour per API key.
/// Uses an in-process <see cref="ConcurrentDictionary"/> — suitable for single-instance
/// deployments. For multi-instance deployments, replace with a distributed cache.
/// </summary>
public sealed class RateLimitMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IConfiguration _config;
    private readonly ILogger<RateLimitMiddleware> _logger;

    // key: apiKey string → sliding window bucket
    private static readonly ConcurrentDictionary<string, SlidingBucket> _buckets = new();

    // Hard cap on the number of tracked buckets. This middleware runs BEFORE the
    // API-key is validated, so the dictionary is keyed by an UNVALIDATED,
    // caller-controlled header value. Without a cap, an unauthenticated client
    // rotating a fresh X-Api-Key on every request would grow this static
    // dictionary without bound → memory-exhaustion DoS. When the cap is reached
    // we first reclaim buckets whose window has fully expired; if it is still
    // full (all buckets active), new keys are simply not tracked — they are
    // rejected moments later by ApiKeyMiddleware anyway, so skipping the limiter
    // for them is safe and bounds memory deterministically.
    private const int MaxBuckets = 50_000;

    public RateLimitMiddleware(RequestDelegate next, IConfiguration config, ILogger<RateLimitMiddleware> logger)
    {
        _next = next;
        _config = config;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Skip Swagger / health
        var path = context.Request.Path.Value ?? string.Empty;
        if (path.StartsWith("/swagger", StringComparison.OrdinalIgnoreCase) ||
            path.StartsWith("/health", StringComparison.OrdinalIgnoreCase))
        {
            await _next(context);
            return;
        }

        if (!context.Request.Headers.TryGetValue("X-Api-Key", out var rawKey) ||
            string.IsNullOrWhiteSpace(rawKey))
        {
            // Let ApiKeyMiddleware handle the 401
            await _next(context);
            return;
        }

        var limit = _config.GetValue("RateLimit:RequestsPerHour", 100);
        var apiKey = rawKey.ToString();

        if (!_buckets.TryGetValue(apiKey, out var bucket))
        {
            // New key: only start tracking it if we are under the memory cap.
            if (_buckets.Count >= MaxBuckets)
            {
                ReclaimExpiredBuckets();
                if (_buckets.Count >= MaxBuckets)
                {
                    // Dictionary saturated with active buckets — don't grow it
                    // further. The (almost certainly invalid) key falls through
                    // to ApiKeyMiddleware, which returns 401.
                    await _next(context);
                    return;
                }
            }
            bucket = _buckets.GetOrAdd(apiKey, _ => new SlidingBucket(TimeSpan.FromHours(1)));
        }

        if (!bucket.TryConsume(limit))
        {
            _logger.LogWarning("Rate limit exceeded for key {Key}", apiKey[..Math.Min(8, apiKey.Length)] + "...");
            context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
            context.Response.Headers["Retry-After"] = "3600";
            context.Response.Headers["X-RateLimit-Limit"] = limit.ToString();
            context.Response.Headers["X-RateLimit-Remaining"] = "0";
            await context.Response.WriteAsJsonAsync(new
            {
                error = "İstek limiti aşıldı. Saatte en fazla 100 istek gönderilebilir.",
                retryAfterSeconds = 3600
            });
            return;
        }

        var remaining = bucket.Remaining(limit);
        context.Response.Headers["X-RateLimit-Limit"]     = limit.ToString();
        context.Response.Headers["X-RateLimit-Remaining"] = remaining.ToString();

        await _next(context);
    }

    /// <summary>
    /// Removes buckets whose sliding window has fully drained (no requests in the
    /// last hour), reclaiming memory from keys that have gone idle. O(n) but only
    /// invoked when the bucket cap is hit, so it is off the hot path.
    /// </summary>
    private static void ReclaimExpiredBuckets()
    {
        var now = DateTime.UtcNow;
        foreach (var kv in _buckets)
        {
            if (kv.Value.IsExpired(now))
                _buckets.TryRemove(kv.Key, out _);
        }
    }

    // -----------------------------------------------------------------------
    // Sliding-window bucket (thread-safe)
    // -----------------------------------------------------------------------

    private sealed class SlidingBucket
    {
        private readonly TimeSpan _window;
        private readonly Queue<DateTime> _timestamps = new();
        private readonly object _lock = new();

        public SlidingBucket(TimeSpan window) => _window = window;

        /// <summary>Returns true and records the request if within limit; false if rate-limited.</summary>
        public bool TryConsume(int limit)
        {
            lock (_lock)
            {
                var now = DateTime.UtcNow;
                var cutoff = now - _window;
                while (_timestamps.Count > 0 && _timestamps.Peek() < cutoff)
                    _timestamps.Dequeue();

                if (_timestamps.Count >= limit)
                    return false;

                _timestamps.Enqueue(now);
                return true;
            }
        }

        public int Remaining(int limit)
        {
            lock (_lock)
            {
                var cutoff = DateTime.UtcNow - _window;
                var active = _timestamps.Count(t => t >= cutoff);
                return Math.Max(0, limit - active);
            }
        }

        /// <summary>
        /// True if the window has fully drained (no timestamps within the last
        /// window). Prunes expired entries as a side effect. Used by the cap-driven
        /// reclaim sweep to decide whether the bucket can be dropped.
        /// </summary>
        public bool IsExpired(DateTime now)
        {
            lock (_lock)
            {
                var cutoff = now - _window;
                while (_timestamps.Count > 0 && _timestamps.Peek() < cutoff)
                    _timestamps.Dequeue();
                return _timestamps.Count == 0;
            }
        }
    }
}
