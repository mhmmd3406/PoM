using PoM.B2B.Api.Models;

namespace PoM.B2B.Api.Services;

public interface IFirestoreService
{
    // ── Trend ─────────────────────────────────────────────────────────────────
    Task<TrendResponse> GetTrendAsync(
        string bankId,
        string businessFamily,
        int fromYear, int fromMonth,
        int toYear, int toMonth,
        CancellationToken ct = default);

    // ── Benchmark (bank vs sector) ────────────────────────────────────────────
    Task<BenchmarkResponse?> GetBenchmarkAsync(
        string bankId,
        string businessFamily,
        int year,
        int month,
        CancellationToken ct = default);

    // ── Head-to-Head (Enterprise) ─────────────────────────────────────────────
    /// <summary>
    /// Returns metric scores for the client bank + up to 3 competitors.
    /// Cells with entry_count &lt; 7 have IsObfuscated=true and null Metrics.
    /// </summary>
    Task<HeadToHeadResponse> GetHeadToHeadAsync(
        string clientBankId,
        IReadOnlyList<string> competitorBankIds,
        string businessFamily,
        int year,
        int month,
        CancellationToken ct = default);

    // ── Retention Risk (Enterprise) ───────────────────────────────────────────
    /// <summary>
    /// Analyses the last <paramref name="lookbackMonths"/> months of snapshots
    /// for every business family of the given bank. Flags families where the
    /// linear slope of the overall score is &lt; -0.1 per month.
    /// </summary>
    Task<RetentionRiskResponse> GetRetentionRiskAsync(
        string bankId,
        int lookbackMonths = 3,
        CancellationToken ct = default);

    // ── DaaS Widget ───────────────────────────────────────────────────────────
    Task<WidgetResponse> GetWidgetDataAsync(
        string bankId,
        string businessFamily,
        CancellationToken ct = default);

    // ── Banks ─────────────────────────────────────────────────────────────────
    Task<IReadOnlyList<string>> GetActiveBankIdsAsync(CancellationToken ct = default);
}
