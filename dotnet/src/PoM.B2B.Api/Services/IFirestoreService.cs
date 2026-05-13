using PoM.B2B.Api.Models;

namespace PoM.B2B.Api.Services;

public interface IFirestoreService
{
    Task<TrendResponse> GetTrendAsync(
        string bankId,
        string businessFamily,
        int fromYear, int fromMonth,
        int toYear, int toMonth,
        CancellationToken ct = default);

    Task<BenchmarkResponse?> GetBenchmarkAsync(
        string bankId,
        string businessFamily,
        int year,
        int month,
        CancellationToken ct = default);

    Task<IReadOnlyList<string>> GetActiveBankIdsAsync(CancellationToken ct = default);
}
