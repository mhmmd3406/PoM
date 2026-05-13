using Google.Cloud.Firestore;
using PoM.B2B.Api.Models;

namespace PoM.B2B.Api.Services;

public sealed class FirestoreService : IFirestoreService
{
    private readonly FirestoreDb _db;
    private const int PrivacyThreshold = 7;

    public FirestoreService(IConfiguration config)
    {
        var projectId = config["Firebase:ProjectId"]
            ?? throw new InvalidOperationException("Firebase:ProjectId not configured");
        _db = FirestoreDb.Create(projectId);
    }

    // -------------------------------------------------------------------------
    // B2B Snapshots — trend data (differential-privacy-safe, delta >= 3)
    // -------------------------------------------------------------------------

    public async Task<TrendResponse> GetTrendAsync(
        string bankId,
        string businessFamily,
        int fromYear, int fromMonth,
        int toYear, int toMonth,
        CancellationToken ct = default)
    {
        var query = _db.Collection("b2b_snapshots")
            .WhereEqualTo("bank_id", bankId)
            .WhereEqualTo("business_family", businessFamily)
            .WhereGreaterThanOrEqualTo("year", fromYear)
            .WhereLessThanOrEqualTo("year", toYear)
            .OrderBy("year")
            .OrderBy("month");

        var snap = await query.GetSnapshotAsync(ct);

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

    // -------------------------------------------------------------------------
    // Benchmark — bank snapshot vs sector aggregation for a given month
    // -------------------------------------------------------------------------

    public async Task<BenchmarkResponse?> GetBenchmarkAsync(
        string bankId,
        string businessFamily,
        int year,
        int month,
        CancellationToken ct = default)
    {
        var snapshotId = $"{bankId}_{businessFamily}_{year}_{month:D2}";
        var sectorId   = $"SECTOR_{businessFamily}_{year}_{month:D2}";

        var bankTask   = _db.Collection("b2b_snapshots").Document(snapshotId).GetSnapshotAsync(ct);
        var sectorTask = _db.Collection("sector_aggregations").Document(sectorId).GetSnapshotAsync(ct);

        await Task.WhenAll(bankTask, sectorTask);

        var bankSnap   = await bankTask;
        var sectorSnap = await sectorTask;

        if (!bankSnap.Exists) return null;

        var bankAvg   = ParseAverages(bankSnap);
        var sectorAvg = sectorSnap.Exists && sectorSnap.GetValue<long>("entry_count") >= PrivacyThreshold
            ? ParseAverages(sectorSnap)
            : null;

        var metrics = BuildMetrics(bankAvg, sectorAvg);
        var entryCount = (int)bankSnap.GetValue<long>("entry_count");

        return new BenchmarkResponse(bankId, businessFamily, year, month, entryCount, metrics);
    }

    // -------------------------------------------------------------------------
    // Banks
    // -------------------------------------------------------------------------

    public async Task<IReadOnlyList<string>> GetActiveBankIdsAsync(CancellationToken ct = default)
    {
        var snap = await _db.Collection("banks")
            .WhereEqualTo("is_active", true)
            .GetSnapshotAsync(ct);

        return snap.Documents.Select(d => d.Id).ToList();
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static TrendPoint ToTrendPoint(DocumentSnapshot doc)
    {
        var avg = ParseAverages(doc);
        var snapshotDate = doc.GetValue<Timestamp>("snapshot_date")
            .ToDateTimeOffset().ToString("yyyy-MM-dd");

        return new TrendPoint(
            Year:         (int)doc.GetValue<long>("year"),
            Month:        (int)doc.GetValue<long>("month"),
            EntryCount:   (int)doc.GetValue<long>("entry_count"),
            SnapshotDate: snapshotDate,
            Averages:     avg);
    }

    private static MetricAverages ParseAverages(DocumentSnapshot doc)
    {
        var map = doc.GetValue<Dictionary<string, object>>("averages");
        double Get(string k) => map.TryGetValue(k, out var v) ? Convert.ToDouble(v) : 0;

        return new MetricAverages(
            Salary:    Get("salary"),
            Benefits:  Get("benefits"),
            WorkModel: Get("work_model"),
            Culture:   Get("culture"),
            Wlb:       Get("wlb"),
            Overall:   Get("overall"));
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
            Name:        r.Name,
            BankValue:   Math.Round(r.BankVal, 2),
            SectorValue: r.SectorVal.HasValue ? Math.Round(r.SectorVal.Value, 2) : null,
            Delta:       r.SectorVal.HasValue ? Math.Round(r.BankVal - r.SectorVal.Value, 2) : null
        )).ToList();
    }
}
