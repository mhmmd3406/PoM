using System.Collections.Concurrent;
using Google.Cloud.Firestore;

namespace PomApi.Services;

/// <summary>
/// Wraps Firestore access with a 5-minute in-memory cache.
/// All public methods are safe for concurrent calls.
/// </summary>
public sealed class FirestoreService
{
    private readonly FirestoreDb _db;
    private readonly TimeSpan _cacheTtl;
    private readonly ILogger<FirestoreService> _logger;

    // Generic cache: key → (value, expiresAt)
    private readonly ConcurrentDictionary<string, (object Value, DateTime ExpiresAt)> _cache = new();

    public FirestoreService(FirestoreDb db, IConfiguration config, ILogger<FirestoreService> logger)
    {
        _db = db;
        _logger = logger;
        var minutes = config.GetValue("Firestore:CacheMinutes", 5);
        _cacheTtl = TimeSpan.FromMinutes(minutes);
    }

    // -----------------------------------------------------------------------
    // Cache helpers
    // -----------------------------------------------------------------------

    private bool TryGetCached<T>(string key, out T value) where T : class
    {
        if (_cache.TryGetValue(key, out var entry) && entry.ExpiresAt > DateTime.UtcNow)
        {
            value = (T)entry.Value;
            return true;
        }
        value = default!;
        return false;
    }

    private void SetCache<T>(string key, T value) where T : class
    {
        _cache[key] = (value, DateTime.UtcNow.Add(_cacheTtl));
    }

    public void InvalidateCache(string key) => _cache.TryRemove(key, out _);

    // -----------------------------------------------------------------------
    // API key lookup
    // -----------------------------------------------------------------------

    /// <summary>Returns the API key record, or null if not found / inactive.</summary>
    public async Task<Models.ApiKeyRecord?> GetApiKeyAsync(string key)
    {
        var cacheKey = $"apikey:{key}";
        if (TryGetCached<Models.ApiKeyRecord>(cacheKey, out var cached))
            return cached;

        try
        {
            var snap = await _db.Collection("daas_api_keys")
                .WhereEqualTo("key", key)
                .WhereEqualTo("active", true)
                .Limit(1)
                .GetSnapshotAsync();

            if (snap.Count == 0)
                return null;

            var doc = snap.Documents[0];
            var record = new Models.ApiKeyRecord(
                KeyId:        doc.Id,
                UserId:       doc.GetValue<string>("userId"),
                CompanyId:    doc.GetValue<string>("companyId"),
                CompanyName:  doc.ContainsField("companyName")  ? doc.GetValue<string>("companyName")  : "Bilinmeyen Şirket",
                IndustryName: doc.ContainsField("industryName") ? doc.GetValue<string>("industryName") : "Genel",
                Key:          doc.GetValue<string>("key"),
                Active:       doc.GetValue<bool>("active"),
                RateLimitHour:doc.ContainsField("rate_limit_hour") ? (int)doc.GetValue<long>("rate_limit_hour") : 100,
                EmployeeCount: doc.ContainsField("employeeCount") ? (int)doc.GetValue<long>("employeeCount") : 0
            );

            SetCache(cacheKey, record);
            return record;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to look up API key");
            return null;
        }
    }

    // -----------------------------------------------------------------------
    // Thresholds
    // -----------------------------------------------------------------------

    public async Task<Dictionary<string, long>> GetThresholdsAsync()
    {
        const string cacheKey = "platform_config/thresholds";
        if (TryGetCached<Dictionary<string, long>>(cacheKey, out var cached))
            return cached;

        try
        {
            var doc = await _db.Collection("platform_config").Document("thresholds").GetSnapshotAsync();
            var raw = doc.Exists
                ? doc.ToDictionary().ToDictionary(kv => kv.Key, kv => Convert.ToInt64(kv.Value))
                : new Dictionary<string, long>();

            // Apply safety floors
            raw["company_min_n"]    = Math.Max(raw.GetValueOrDefault("company_min_n",    15), 7);
            raw["department_min_n"] = Math.Max(raw.GetValueOrDefault("department_min_n", 10), 5);

            SetCache(cacheKey, raw);
            return raw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to load thresholds, returning defaults");
            return new Dictionary<string, long>
            {
                ["company_min_n"]    = 15,
                ["department_min_n"] = 10,
            };
        }
    }

    // -----------------------------------------------------------------------
    // Check-ins
    // -----------------------------------------------------------------------

    /// <summary>Returns all check-ins for a company, ordered by created_at descending.</summary>
    public async Task<IReadOnlyList<CheckinDocument>> GetCompanyCheckinsAsync(string companyId)
    {
        var cacheKey = $"checkins:company:{companyId}";
        if (TryGetCached<IReadOnlyList<CheckinDocument>>(cacheKey, out var cached))
            return cached;

        try
        {
            var snap = await _db.Collection("checkins")
                .WhereEqualTo("companyId", companyId)
                .OrderByDescending("created_at")
                .Limit(2000)
                .GetSnapshotAsync();

            var docs = snap.Documents
                .Select(ParseCheckin)
                .Where(c => c is not null)
                .Cast<CheckinDocument>()
                .ToList();

            var result = (IReadOnlyList<CheckinDocument>)docs;
            SetCache(cacheKey, result);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to load checkins for company {CompanyId}", companyId);
            return Array.Empty<CheckinDocument>();
        }
    }

    /// <summary>Returns check-ins within the last <paramref name="days"/> days.</summary>
    public async Task<IReadOnlyList<CheckinDocument>> GetCompanyCheckinsAsync(string companyId, int days)
    {
        var all = await GetCompanyCheckinsAsync(companyId);
        var cutoff = DateTimeOffset.UtcNow.AddDays(-days);
        return all.Where(c => c.CreatedAt >= cutoff).ToList();
    }

    // -----------------------------------------------------------------------
    // Company metadata (companies collection)
    // -----------------------------------------------------------------------

    public async Task<CompanyMetadata?> GetCompanyMetadataAsync(string companyId)
    {
        var cacheKey = $"company:{companyId}";
        if (TryGetCached<CompanyMetadata>(cacheKey, out var cached))
            return cached;

        try
        {
            var doc = await _db.Collection("companies").Document(companyId).GetSnapshotAsync();
            if (!doc.Exists) return null;

            var meta = new CompanyMetadata(
                CompanyId:    companyId,
                CompanyName:  doc.ContainsField("name")         ? doc.GetValue<string>("name")         : "Bilinmeyen Şirket",
                IndustryName: doc.ContainsField("industry")     ? doc.GetValue<string>("industry")     : "Genel",
                EmployeeCount:doc.ContainsField("employeeCount")? (int)doc.GetValue<long>("employeeCount") : 0
            );
            SetCache(cacheKey, meta);
            return meta;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to load company metadata for {CompanyId}", companyId);
            return null;
        }
    }

    // -----------------------------------------------------------------------
    // Industry benchmark aggregates
    // -----------------------------------------------------------------------

    /// <summary>
    /// Returns pre-computed industry benchmark from platform_config/benchmarks.
    /// Falls back to neutral 50.0 values if not found.
    /// </summary>
    public async Task<BenchmarkData> GetIndustryBenchmarkAsync(string industryName)
    {
        var cacheKey = $"benchmark:{industryName}";
        if (TryGetCached<BenchmarkData>(cacheKey, out var cached))
            return cached;

        try
        {
            var doc = await _db.Collection("platform_config").Document("benchmarks").GetSnapshotAsync();
            if (doc.Exists && doc.ContainsField(industryName))
            {
                var raw = doc.GetValue<Dictionary<string, object>>(industryName);
                var data = new BenchmarkData(
                    Mood:    Convert.ToDouble(raw.GetValueOrDefault("mood",    50)),
                    Stress:  Convert.ToDouble(raw.GetValueOrDefault("stress",  50)),
                    Team:    Convert.ToDouble(raw.GetValueOrDefault("team",    50)),
                    Growth:  Convert.ToDouble(raw.GetValueOrDefault("growth",  50)),
                    Balance: Convert.ToDouble(raw.GetValueOrDefault("balance", 50))
                );
                SetCache(cacheKey, data);
                return data;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not load benchmark for industry {Industry}, using defaults", industryName);
        }

        return new BenchmarkData(50, 50, 50, 50, 50);
    }

    // -----------------------------------------------------------------------
    // Parse helpers
    // -----------------------------------------------------------------------

    private static CheckinDocument? ParseCheckin(DocumentSnapshot doc)
    {
        try
        {
            var scores = doc.ContainsField("scores")
                ? doc.GetValue<Dictionary<string, object>>("scores")
                    .ToDictionary(kv => kv.Key, kv => Convert.ToDouble(kv.Value))
                : new Dictionary<string, double>();

            var createdAt = doc.ContainsField("created_at")
                ? doc.GetValue<Timestamp>("created_at").ToDateTimeOffset()
                : DateTimeOffset.MinValue;

            return new CheckinDocument(
                Id:           doc.Id,
                UserId:       doc.ContainsField("userId")     ? doc.GetValue<string>("userId")     : string.Empty,
                CompanyId:    doc.ContainsField("companyId")  ? doc.GetValue<string>("companyId")  : null,
                Department:   doc.ContainsField("department") ? doc.GetValue<string>("department") : null,
                Scores:       scores,
                CreatedAt:    createdAt
            );
        }
        catch
        {
            return null;
        }
    }
}

// ---------------------------------------------------------------------------
// Data shapes used internally
// ---------------------------------------------------------------------------

public record CheckinDocument(
    string Id,
    string UserId,
    string? CompanyId,
    string? Department,
    Dictionary<string, double> Scores,
    DateTimeOffset CreatedAt
);

public record CompanyMetadata(
    string CompanyId,
    string CompanyName,
    string IndustryName,
    int EmployeeCount
);

public record BenchmarkData(
    double Mood,
    double Stress,
    double Team,
    double Growth,
    double Balance
);
