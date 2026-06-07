using PomApi.Models;

namespace PomApi.Services;

/// <summary>
/// Pure business-logic aggregation — no I/O.  All methods operate on pre-fetched data.
/// </summary>
public static class InsightsAggregator
{
    // -----------------------------------------------------------------------
    // Canonical dimension keys stored in each check-in's `scores` map. These
    // must match the mobile CheckinModel + the computeInsights Cloud Function;
    // the previous short keys ("mood"/"stress"/…) never existed in the data and
    // made every average resolve to 0 (the dead B2B-revenue bug).
    // -----------------------------------------------------------------------
    private static readonly string[] DimKeys =
        { "overallMood", "workStress", "teamHarmony", "personalGrowth", "workLifeBalance" };

    // -----------------------------------------------------------------------
    // Score averaging
    // -----------------------------------------------------------------------

    /// <summary>
    /// Computes per-dimension averages from a collection of check-ins.
    /// Returns null if the collection is empty.
    /// </summary>
    public static Dimensions? AverageDimensions(IReadOnlyList<CheckinDocument> checkins)
    {
        if (checkins.Count == 0) return null;

        double Avg(string key)
        {
            var vals = checkins
                .Select(c => c.Scores.GetValueOrDefault(key, double.NaN))
                .Where(v => !double.IsNaN(v))
                .ToList();
            return vals.Count > 0 ? vals.Average() : 0;
        }

        // Output field names (Mood/Stress/…) are the public API contract; only
        // the Firestore read keys change to the canonical camelCase vocabulary.
        return new Dimensions(
            Mood:    Math.Round(Avg("overallMood"),     2),
            Stress:  Math.Round(Avg("workStress"),      2),
            Team:    Math.Round(Avg("teamHarmony"),     2),
            Growth:  Math.Round(Avg("personalGrowth"),  2),
            Balance: Math.Round(Avg("workLifeBalance"), 2)
        );
    }

    /// <summary>
    /// Computes the composite wellbeing score (0–100) as the arithmetic mean
    /// of all five dimension averages.
    /// </summary>
    public static double CompositeScore(Dimensions dims)
    {
        var avg = (dims.Mood + dims.Stress + dims.Team + dims.Growth + dims.Balance) / 5.0;
        return Math.Round(avg, 1);
    }

    // -----------------------------------------------------------------------
    // OLS-based retention risk
    // -----------------------------------------------------------------------

    /// <summary>
    /// Estimates retention risk using OLS trend slope over weekly composite scores.
    /// A declining trend increases risk; an improving trend decreases it.
    /// </summary>
    public static RetentionRisk ComputeRetentionRisk(IReadOnlyList<CheckinDocument> checkins)
    {
        // Group into weeks, compute weekly composite
        var weekly = checkins
            .GroupBy(c => WeekStart(c.CreatedAt))
            .OrderBy(g => g.Key)
            .Select(g =>
            {
                var dims = AverageDimensions(g.ToList());
                return dims is null ? 0 : CompositeScore(dims);
            })
            .ToList();

        var slope = OlsSlope(weekly);
        // slope in points/week: < -0.5 → high risk, 0.5 to -0.5 → medium, > 0.5 → low
        if (slope < -0.5) return RetentionRisk.High;
        if (slope <  0.5) return RetentionRisk.Medium;
        return RetentionRisk.Low;
    }

    // -----------------------------------------------------------------------
    // Trend points (weekly buckets)
    // -----------------------------------------------------------------------

    public static IReadOnlyList<TrendPoint> BuildTrendPoints(
        IReadOnlyList<CheckinDocument> checkins, int days)
    {
        var cutoff = DateTimeOffset.UtcNow.AddDays(-days);
        var inWindow = checkins.Where(c => c.CreatedAt >= cutoff).ToList();

        var grouped = inWindow
            .GroupBy(c => WeekStart(c.CreatedAt))
            .OrderBy(g => g.Key);

        var points = new List<TrendPoint>();
        foreach (var g in grouped)
        {
            var docs = g.ToList();
            var dims = AverageDimensions(docs);
            if (dims is null) continue;

            points.Add(new TrendPoint(
                WeekStart:        g.Key,
                Score:            CompositeScore(dims),
                Dimensions:       dims,
                ParticipantCount: docs.Select(c => c.UserId).Distinct().Count()
            ));
        }
        return points;
    }

    // -----------------------------------------------------------------------
    // Department aggregation
    // -----------------------------------------------------------------------

    public static IReadOnlyList<DepartmentData> AggregateDepartments(
        IReadOnlyList<CheckinDocument> checkins,
        int departmentMinN)
    {
        var byDept = checkins
            .Where(c => !string.IsNullOrEmpty(c.Department))
            .GroupBy(c => c.Department!);

        var result = new List<DepartmentData>();
        foreach (var g in byDept)
        {
            var docs = g.ToList();
            var uniqueUsers = docs.Select(c => c.UserId).Distinct().Count();
            var meetsThreshold = uniqueUsers >= departmentMinN;

            var dims = meetsThreshold
                ? AverageDimensions(docs) ?? new Dimensions(0, 0, 0, 0, 0)
                : new Dimensions(0, 0, 0, 0, 0);

            result.Add(new DepartmentData(
                DepartmentId:   g.Key,
                DepartmentName: g.Key,
                Score:          meetsThreshold ? CompositeScore(dims) : 0,
                Dimensions:     dims,
                EmployeeCount:  uniqueUsers,
                CheckinCount:   docs.Count,
                MeetsThreshold: meetsThreshold
            ));
        }

        return result.OrderByDescending(d => d.MeetsThreshold)
                     .ThenByDescending(d => d.Score)
                     .ToList();
    }

    // -----------------------------------------------------------------------
    // Benchmark percentile
    // -----------------------------------------------------------------------

    /// <summary>
    /// Approximates a percentile rank given a company score and industry average,
    /// assuming a roughly normal distribution with sigma ≈ 15.
    /// </summary>
    public static double ApproximatePercentile(double companyScore, double industryAvg, double sigma = 15.0)
    {
        var z = (companyScore - industryAvg) / sigma;
        // Standard normal CDF approximation (Abramowitz & Stegun)
        var p = NormalCdf(z) * 100.0;
        return Math.Round(Math.Clamp(p, 1, 99), 1);
    }

    // -----------------------------------------------------------------------
    // OLS helpers
    // -----------------------------------------------------------------------

    private static double OlsSlope(IReadOnlyList<double> values)
    {
        int n = values.Count;
        if (n < 2) return 0;
        double xMean = (n - 1) / 2.0;
        double yMean = values.Average();
        double num = 0, den = 0;
        for (int i = 0; i < n; i++)
        {
            num += (i - xMean) * (values[i] - yMean);
            den += (i - xMean) * (i - xMean);
        }
        return den == 0 ? 0 : num / den;
    }

    private static double NormalCdf(double z)
    {
        // Abramowitz & Stegun approximation (maximum error < 7.5e-8)
        const double a1 =  0.254829592;
        const double a2 = -0.284496736;
        const double a3 =  1.421413741;
        const double a4 = -1.453152027;
        const double a5 =  1.061405429;
        const double p  =  0.3275911;

        int sign = z < 0 ? -1 : 1;
        z = Math.Abs(z) / Math.Sqrt(2.0);
        double t = 1.0 / (1.0 + p * z);
        double y = 1.0 - ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * Math.Exp(-z * z);
        return 0.5 * (1.0 + sign * y);
    }

    private static DateTimeOffset WeekStart(DateTimeOffset dt)
    {
        // ISO week: Monday as first day
        int daysToSubtract = ((int)dt.DayOfWeek + 6) % 7;
        return dt.AddDays(-daysToSubtract).Date;
    }
}
