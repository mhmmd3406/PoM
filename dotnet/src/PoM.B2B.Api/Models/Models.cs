namespace PoM.B2B.Api.Models;

// ── Subscription tier ────────────────────────────────────────────────────────

public enum SubscriptionTier
{
    Free         = 0,
    Pro          = 1,
    Standard     = 2,
    Professional = 3,
    Enterprise   = 4,
    DaaS         = 5,
}

public static class SubscriptionTierExtensions
{
    public static SubscriptionTier Parse(string? raw) => raw?.ToLowerInvariant() switch
    {
        "pro"          => SubscriptionTier.Pro,
        "standard"     => SubscriptionTier.Standard,
        "professional" => SubscriptionTier.Professional,
        "enterprise"   => SubscriptionTier.Enterprise,
        "daas"         => SubscriptionTier.DaaS,
        _              => SubscriptionTier.Free,
    };

    public static bool IsAtLeast(this SubscriptionTier actual, SubscriptionTier required)
        => actual >= required;
}

// ── Auth claims ──────────────────────────────────────────────────────────────

/// <summary>Populated by B2BAuthMiddleware for every authenticated B2B request.</summary>
public record B2BClaims(string BankId, string Email, SubscriptionTier Tier);

/// <summary>Populated by DaasAuthMiddleware for Widget API requests.</summary>
public record DaasClaims(string ApiKeyId, string OwnerBankId, int RateLimitPerHour);

// ── Shared metric types ──────────────────────────────────────────────────────

public record MetricAverages(
    double Salary,
    double Benefits,
    double WorkModel,
    double Culture,
    double Wlb,
    double Overall);

// ── Trend ────────────────────────────────────────────────────────────────────

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

// ── Benchmark (bank vs sector) ───────────────────────────────────────────────

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

// ── Head-to-Head benchmarking ────────────────────────────────────────────────

public record HeadToHeadEntry(
    string BankId,
    bool IsObfuscated,
    int? EntryCount,
    IReadOnlyList<BenchmarkMetric>? Metrics);

public record HeadToHeadResponse(
    string BusinessFamily,
    int Year,
    int Month,
    HeadToHeadEntry ClientBank,
    IReadOnlyList<HeadToHeadEntry> Competitors);

// ── Retention risk ───────────────────────────────────────────────────────────

public record RetentionRiskDepartment(
    string BusinessFamily,
    double ScoreMonth1,
    double ScoreMonth3,
    double SlopePerMonth,
    string RiskLevel);

public record RetentionRiskResponse(
    string BankId,
    int AnalysisMonths,
    IReadOnlyList<RetentionRiskDepartment> Departments);

// ── DaaS Widget ──────────────────────────────────────────────────────────────

public record WidgetResponse(
    string BankId,
    string BusinessFamily,
    double? OverallScore,
    double? CultureScore,
    double? WlbScore,
    int? EntryCount,
    bool IsObfuscated,
    string Timestamp);

// ── Report ───────────────────────────────────────────────────────────────────

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
    string Status,
    string? DownloadUrl,
    DateTimeOffset? GeneratedAt);
