namespace PomApi.Services;

/// <summary>
/// Reads privacy thresholds from Firestore (via <see cref="FirestoreService"/> cache)
/// and exposes strongly-typed accessors.
/// </summary>
public sealed class ThresholdService
{
    private readonly FirestoreService _firestore;

    public ThresholdService(FirestoreService firestore)
    {
        _firestore = firestore;
    }

    /// <summary>Minimum company-level check-in count to expose aggregated data.</summary>
    public async Task<int> GetCompanyMinNAsync()
    {
        var thresholds = await _firestore.GetThresholdsAsync();
        return (int)thresholds.GetValueOrDefault("company_min_n", 15);
    }

    /// <summary>Minimum department-level check-in count to expose department data.</summary>
    public async Task<int> GetDepartmentMinNAsync()
    {
        var thresholds = await _firestore.GetThresholdsAsync();
        return (int)thresholds.GetValueOrDefault("department_min_n", 10);
    }
}
