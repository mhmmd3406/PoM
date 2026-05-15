using Google.Cloud.Firestore;
using PoM.B2B.Api.Models;

namespace PoM.B2B.Api.Services;

public sealed class FirestoreService : IFirestoreService
{
    private readonly FirestoreDb _db;

    private PlatformThresholds? _cachedThresholds;
    private DateTimeOffset _thresholdsCachedAt = DateTimeOffset.MinValue;
    private static readonly TimeSpan ThresholdsCacheTtl = TimeSpan.FromMinutes(5);

    public FirestoreService(IConfiguration config)
    {
        var projectId = config["Firebase:ProjectId"]
            ?? throw new InvalidOperationException("Firebase:ProjectId not configured");
        _db = FirestoreDb.Create(projectId);
    }

    private async Task<PlatformThresholds> GetThresholdsAsync(CancellationToken ct = default)
    {
        if (_cachedThresholds is not null
            && DateTimeOffset.UtcNow - _thresholdsCachedAt < ThresholdsCacheTtl)
            return _cachedThresholds;

        try
        {
            var snap = await _db.Document("platform_config/thresholds").GetSnapshotAsync(ct);
            _cachedThresholds = snap.Exists
                ? new PlatformThresholds(
                    CompanyThreshold:    Math.Max(7,  SafeInt(snap, "company_privacy_threshold",    15)),
                    DepartmentThreshold: Math.Max(5,  SafeInt(snap, "department_privacy_threshold", 10)),
                    MinEmployees:        Math.Max(0,  SafeInt(snap, "min_company_employees",        200)),
                    MaxHeadToHead:       Math.Min(10, Math.Max(1, SafeInt(snap, "max_head_to_head_competitors", 3))),
                    RetentionMaxMonths:  Math.Min(24, Math.Max(2, SafeInt(snap, "retention_risk_max_months",    12))))
                : PlatformThresholds.Defaults;
        }
        catch { _cachedThresholds = PlatformThresholds.Defaults; }

        _thresholdsCachedAt = DateTimeOffset.UtcNow;
        return _cachedThresholds;
    }

    private static int SafeInt(DocumentSnapshot snap, string field, int fallback)
    {
        try { return (int)snap.GetValue<long>(field); }
        catch { return fallback; }
    }

    // ── Trend ─────────────────────────────────────────────────────────────────

    public async Task<TrendResponse> GetTrendAsync(
        string bankId, string businessFamily,
        int fromYear, int fromMonth, int toYear, int toMonth,
        CancellationToken ct = default)
    {
        var snap = await _db.Collection("b2b_snapshots")
            .WhereEqualTo("bank_id", bankId)
            .WhereEqualTo("business_family", businessFamily)
            .WhereGreaterThanOrEqualTo("year", fromYear)
            .WhereLessThanOrEqualTo("year", toYear)
            .OrderBy("year").OrderBy("month")
            .GetSnapshotAsync(ct);

        var points = snap.Documents
            .Select(ToTrendPoint)
            .Where(p =>
            {
                if (p.Year == fromYear && p.Month < fromMonth) return false;
                if (p.Year == toYear   && p.Month > toMonth)   return false;
                return true;
            })
            .ToList();

        return new TrendResponse(bankId, businessFamily, points);
    }

    // ── Benchmark ─────────────────────────────────────────────────────────────

    public async Task<BenchmarkResponse?> GetBenchmarkAsync(
        string bankId, string businessFamily, int year, int month,
        CancellationToken ct = default)
    {
        var snapshotId = $"{bankId}_{businessFamily}_{year}_{month:D2}";
        var sectorId   = $"SECTOR_{businessFamily}_{year}_{month:D2}";

        var bankTask   = _db.Collection("b2b_snapshots").Document(snapshotId).GetSnapshotAsync(ct);
        var sectorTask = _db.Collection("sector_aggregations").Document(sectorId).GetSnapshotAsync(ct);
        await Task.WhenAll(bankTask, sectorTask);

        var bankSnap   = bankTask.Result;
        var sectorSnap = sectorTask.Result;

        if (!bankSnap.Exists) return null;

        var cfg = await GetThresholdsAsync(ct);
        var bankAvg   = ParseAverages(bankSnap);
        var sectorAvg = sectorSnap.Exists
            && sectorSnap.GetValue<long>("entry_count") >= cfg.CompanyThreshold
            ? ParseAverages(sectorSnap) : null;

        return new BenchmarkResponse(
            bankId, businessFamily, year, month,
            (int)bankSnap.GetValue<long>("entry_count"),
            BuildMetrics(bankAvg, sectorAvg));
    }

    // ── Head-to-Head ──────────────────────────────────────────────────────────

    public async Task<HeadToHeadResponse> GetHeadToHeadAsync(
        string clientBankId,
        IReadOnlyList<string> competitorBankIds,
        string businessFamily, int year, int month,
        CancellationToken ct = default)
    {
        var cfg = await GetThresholdsAsync(ct);

        var allBankIds = new[] { clientBankId }.Concat(competitorBankIds).ToList();

        var tasks = allBankIds.Select(bankId =>
        {
            var docId = $"{bankId}_{businessFamily}_{year}_{month:D2}";
            return _db.Collection("b2b_snapshots").Document(docId).GetSnapshotAsync(ct);
        }).ToList();

        var sectorId   = $"SECTOR_{businessFamily}_{year}_{month:D2}";
        var sectorTask = _db.Collection("sector_aggregations").Document(sectorId).GetSnapshotAsync(ct);

        await Task.WhenAll(tasks.Concat([sectorTask]));

        var sectorSnap = sectorTask.Result;
        var threshold  = businessFamily == "all" ? cfg.CompanyThreshold : cfg.DepartmentThreshold;
        var sectorAvg  = sectorSnap.Exists
            && sectorSnap.GetValue<long>("entry_count") >= threshold
            ? ParseAverages(sectorSnap) : null;

        HeadToHeadEntry BuildEntry(string bankId, DocumentSnapshot snap)
        {
            if (!snap.Exists) return new HeadToHeadEntry(bankId, true, null, null);

            var count = (int)snap.GetValue<long>("entry_count");
            if (count < threshold)
                return new HeadToHeadEntry(bankId, true, null, null);

            var avg = ParseAverages(snap);
            return new HeadToHeadEntry(bankId, false, count, BuildMetrics(avg, sectorAvg));
        }

        var snaps     = tasks.Select(t => t.Result).ToList();
        var clientEntry = BuildEntry(clientBankId, snaps[0]);

        var competitors = competitorBankIds
            .Zip(snaps.Skip(1), (id, snap) => BuildEntry(id, snap))
            .ToList();

        return new HeadToHeadResponse(businessFamily, year, month, clientEntry, competitors);
    }

    // ── Retention Risk ────────────────────────────────────────────────────────

    public async Task<RetentionRiskResponse> GetRetentionRiskAsync(
        string bankId, int lookbackMonths = 3,
        CancellationToken ct = default)
    {
        var now   = DateTimeOffset.UtcNow;
        var start = now.AddMonths(-(lookbackMonths - 1));

        var snap = await _db.Collection("b2b_snapshots")
            .WhereEqualTo("bank_id", bankId)
            .WhereGreaterThanOrEqualTo("year", start.Year)
            .OrderBy("year").OrderBy("month")
            .GetSnapshotAsync(ct);

        // Group by business_family → ordered list of (month_index, overall)
        var byFamily = new Dictionary<string, List<(int idx, double overall)>>();

        var cfg = await GetThresholdsAsync(ct);

        foreach (var doc in snap.Documents)
        {
            var year  = (int)doc.GetValue<long>("year");
            var month = (int)doc.GetValue<long>("month");
            if (year == start.Year && month < start.Month) continue;
            var family = doc.GetValue<string>("business_family");
            var t = family == "all" ? cfg.CompanyThreshold : cfg.DepartmentThreshold;
            if (doc.GetValue<long>("entry_count") < t) continue;

            var family  = doc.GetValue<string>("business_family");
            var overall = ParseAverages(doc).Overall;
            var idx     = (year - start.Year) * 12 + (month - start.Month);

            if (!byFamily.ContainsKey(family)) byFamily[family] = [];
            byFamily[family].Add((idx, overall));
        }

        var departments = byFamily
            .Where(kv => kv.Value.Count >= 2)
            .Select(kv =>
            {
                var pts      = kv.Value.OrderBy(p => p.idx).ToList();
                var slope    = LinearSlope(pts);
                var first    = pts.First().overall;
                var last     = pts.Last().overall;
                var riskLevel = slope < -0.2 ? "high"
                              : slope < -0.1 ? "moderate"
                              : "low";

                return new RetentionRiskDepartment(
                    BusinessFamily: kv.Key,
                    ScoreMonth1:    Math.Round(first, 2),
                    ScoreMonth3:    Math.Round(last,  2),
                    SlopePerMonth:  Math.Round(slope, 3),
                    RiskLevel:      riskLevel);
            })
            .OrderBy(d => d.SlopePerMonth)   // worst first
            .ToList();

        return new RetentionRiskResponse(bankId, lookbackMonths, departments);
    }

    // ── DaaS Widget ───────────────────────────────────────────────────────────

    public async Task<WidgetResponse> GetWidgetDataAsync(
        string bankId, string businessFamily,
        CancellationToken ct = default)
    {
        // Read from sector_aggregations (not bank snapshots) for widget data —
        // widgets show sector context, not bank-specific data that requires B2B access.
        // For bank-specific widgets, reads from aggregations collection (overall only).
        var now    = DateTimeOffset.UtcNow;
        var docId  = $"{bankId}_{businessFamily}_{now.Year}_{now.Month:D2}";
        var snap   = await _db.Collection("aggregations").Document(docId).GetSnapshotAsync(ct);

        var timestamp = DateTimeOffset.UtcNow.ToString("O");

        if (!snap.Exists)
            return new WidgetResponse(bankId, businessFamily, null, null, null, null, true, timestamp);

        var cfg   = await GetThresholdsAsync(ct);
        var count = (int)snap.GetValue<long>("entry_count");
        var widgetThreshold = businessFamily == "all" ? cfg.CompanyThreshold : cfg.DepartmentThreshold;
        if (count < widgetThreshold)
            return new WidgetResponse(bankId, businessFamily, null, null, null, null, true, timestamp);

        var avg = ParseAverages(snap);
        return new WidgetResponse(
            bankId, businessFamily,
            Math.Round(avg.Overall,  2),
            Math.Round(avg.Culture,  2),
            Math.Round(avg.Wlb,      2),
            count, false, timestamp);
    }

    // ── Banks ─────────────────────────────────────────────────────────────────

    public async Task<IReadOnlyList<string>> GetActiveBankIdsAsync(CancellationToken ct = default)
    {
        var snap = await _db.Collection("banks")
            .WhereEqualTo("is_active", true)
            .GetSnapshotAsync(ct);
        return snap.Documents.Select(d => d.Id).ToList();
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static TrendPoint ToTrendPoint(DocumentSnapshot doc)
    {
        var avg = ParseAverages(doc);
        var snapshotDate = doc.GetValue<Timestamp>("snapshot_date")
            .ToDateTimeOffset().ToString("yyyy-MM-dd");
        return new TrendPoint(
            (int)doc.GetValue<long>("year"),
            (int)doc.GetValue<long>("month"),
            (int)doc.GetValue<long>("entry_count"),
            snapshotDate, avg);
    }

    private static MetricAverages ParseAverages(DocumentSnapshot doc)
    {
        var map = doc.GetValue<Dictionary<string, object>>("averages");
        double Get(string k) => map.TryGetValue(k, out var v) ? Convert.ToDouble(v) : 0;
        return new MetricAverages(
            Get("salary"), Get("benefits"), Get("work_model"),
            Get("culture"), Get("wlb"), Get("overall"));
    }

    private static IReadOnlyList<BenchmarkMetric> BuildMetrics(
        MetricAverages bank, MetricAverages? sector)
    {
        (string Name, double BankVal, double? SectorVal)[] raw =
        [
            ("Salary",           bank.Salary,    sector?.Salary),
            ("Benefits",         bank.Benefits,  sector?.Benefits),
            ("Work Model",       bank.WorkModel, sector?.WorkModel),
            ("Culture",          bank.Culture,   sector?.Culture),
            ("Work-Life Balance",bank.Wlb,       sector?.Wlb),
            ("Overall",          bank.Overall,   sector?.Overall),
        ];
        return raw.Select(r => new BenchmarkMetric(
            r.Name,
            Math.Round(r.BankVal, 2),
            r.SectorVal.HasValue ? Math.Round(r.SectorVal.Value, 2) : null,
            r.SectorVal.HasValue ? Math.Round(r.BankVal - r.SectorVal.Value, 2) : null
        )).ToList();
    }

    /// <summary>Ordinary least-squares slope for a set of (x, y) points.</summary>
    private static double LinearSlope(List<(int idx, double overall)> pts)
    {
        var n    = pts.Count;
        var xMean = pts.Average(p => (double)p.idx);
        var yMean = pts.Average(p => p.overall);

        var num = pts.Sum(p => (p.idx - xMean) * (p.overall - yMean));
        var den = pts.Sum(p => Math.Pow(p.idx - xMean, 2));

        return den == 0 ? 0 : num / den;
    }
}
