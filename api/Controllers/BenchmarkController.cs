using Microsoft.AspNetCore.Mvc;
using PomApi.Middleware;
using PomApi.Models;
using PomApi.Services;

namespace PomApi.Controllers;

[ApiController]
[Route("api/v1")]
[Produces("application/json")]
public sealed class BenchmarkController : ControllerBase
{
    private readonly FirestoreService _firestore;
    private readonly ThresholdService _thresholds;

    public BenchmarkController(FirestoreService firestore, ThresholdService thresholds)
    {
        _firestore = firestore;
        _thresholds = thresholds;
    }

    /// <summary>
    /// Returns industry benchmark comparison for the authenticated company.
    /// Percentile ranks are approximated using a normal distribution (σ = 15).
    /// </summary>
    /// <response code="200">Benchmark data returned successfully.</response>
    [HttpGet("benchmark")]
    [ProducesResponseType(typeof(BenchmarkResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetBenchmark()
    {
        var ctx = ApiKeyMiddleware.GetCompanyContext(HttpContext);
        var minN = await _thresholds.GetCompanyMinNAsync();

        var checkins = await _firestore.GetCompanyCheckinsAsync(ctx.CompanyId);
        var industryBenchmark = await _firestore.GetIndustryBenchmarkAsync(ctx.IndustryName);

        // Compute company scores (return neutral data if below threshold)
        Dimensions companyDims;
        if (checkins.Count < minN)
        {
            companyDims = new Dimensions(50, 50, 50, 50, 50);
        }
        else
        {
            companyDims = InsightsAggregator.AverageDimensions(checkins)
                          ?? new Dimensions(50, 50, 50, 50, 50);
        }

        // Build per-dimension benchmark entries
        var dimEntries = new List<BenchmarkDimension>
        {
            BuildEntry("mood",    companyDims.Mood,    industryBenchmark.Mood),
            BuildEntry("stress",  companyDims.Stress,  industryBenchmark.Stress),
            BuildEntry("team",    companyDims.Team,    industryBenchmark.Team),
            BuildEntry("growth",  companyDims.Growth,  industryBenchmark.Growth),
            BuildEntry("balance", companyDims.Balance, industryBenchmark.Balance),
        };

        var overallCompany  = InsightsAggregator.CompositeScore(companyDims);
        var overallIndustry = (industryBenchmark.Mood + industryBenchmark.Stress +
                               industryBenchmark.Team + industryBenchmark.Growth +
                               industryBenchmark.Balance) / 5.0;
        var overallPercentile = InsightsAggregator.ApproximatePercentile(overallCompany, overallIndustry);

        return Ok(new BenchmarkResponse(
            CompanyId:            ctx.CompanyId,
            IndustryName:         ctx.IndustryName,
            OverallPercentile:    overallPercentile,
            Dimensions:           dimEntries,
            TopQuartileThreshold: 75.0
        ));
    }

    private static BenchmarkDimension BuildEntry(string key, double companyScore, double industryAvg)
    {
        return new BenchmarkDimension(
            Dimension:       key,
            CompanyScore:    Math.Round(companyScore,  2),
            IndustryAverage: Math.Round(industryAvg,   2),
            Percentile:      InsightsAggregator.ApproximatePercentile(companyScore, industryAvg)
        );
    }
}
