namespace PoM.B2B.Api.Models;

public record B2BClaims(string BankId, string Email);

public record MetricAverages(
    double Salary,
    double Benefits,
    double WorkModel,
    double Culture,
    double Wlb,
    double Overall);

public record TrendPoint(
    int Year,
    int Month,
    int EntryCount,
    string SnapshotDate,
    MetricAverages Averages);

public record TrendResponse(
    string BankId,
    string BusinessFamily,
    IReadOnlyList<TrendPoint> Points);

public record BenchmarkMetric(
    string Name,
    double BankValue,
    double? SectorValue,
    double? Delta);

public record BenchmarkResponse(
    string BankId,
    string BusinessFamily,
    int Year,
    int Month,
    int BankEntryCount,
    IReadOnlyList<BenchmarkMetric> Metrics);

public record ReportRequest(
    string BusinessFamily,
    int FromYear,
    int FromMonth,
    int ToYear,
    int ToMonth,
    ReportFormat Format = ReportFormat.Json);

public enum ReportFormat { Json, Excel }

public record ReportStatus(
    string ReportId,
    string Status,       // queued | generating | ready | error
    string? DownloadUrl,
    DateTimeOffset? GeneratedAt);
