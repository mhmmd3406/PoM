using Microsoft.AspNetCore.Mvc;
using PomApi.Middleware;
using PomApi.Models;
using PomApi.Services;

namespace PomApi.Controllers;

[ApiController]
[Route("api/v1")]
[Produces("application/json")]
public sealed class WellbeingController : ControllerBase
{
    private readonly FirestoreService _firestore;
    private readonly ThresholdService _thresholds;
    private readonly ILogger<WellbeingController> _logger;

    public WellbeingController(
        FirestoreService firestore,
        ThresholdService thresholds,
        ILogger<WellbeingController> logger)
    {
        _firestore = firestore;
        _thresholds = thresholds;
        _logger = logger;
    }

    /// <summary>
    /// Returns the authenticated company's wellbeing overview.
    /// Enforces the N≥15 minimum participation threshold.
    /// </summary>
    /// <response code="200">Wellbeing data returned successfully.</response>
    /// <response code="451">Insufficient participation data (below privacy threshold).</response>
    [HttpGet("wellbeing")]
    [ProducesResponseType(typeof(WellbeingResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status451UnavailableForLegalReasons)]
    public async Task<IActionResult> GetWellbeing()
    {
        var ctx = ApiKeyMiddleware.GetCompanyContext(HttpContext);
        var minN = await _thresholds.GetCompanyMinNAsync();

        var checkins = await _firestore.GetCompanyCheckinsAsync(ctx.CompanyId);

        if (checkins.Count < minN)
        {
            _logger.LogInformation(
                "Company {CompanyId} has {Count} checkins — below threshold {MinN}",
                ctx.CompanyId, checkins.Count, minN);

            return StatusCode(StatusCodes.Status451UnavailableForLegalReasons, new
            {
                error = $"Gizlilik eşiği sağlanmadı. Minimum {minN} katılım gereklidir.",
                currentCount = checkins.Count,
                requiredCount = minN
            });
        }

        var dims = InsightsAggregator.AverageDimensions(checkins)!;
        var score = InsightsAggregator.CompositeScore(dims);
        var risk = InsightsAggregator.ComputeRetentionRisk(checkins);

        // Participation rate: unique users this calendar month / total employees
        var monthStart = new DateTimeOffset(DateTimeOffset.UtcNow.Year, DateTimeOffset.UtcNow.Month, 1, 0, 0, 0, TimeSpan.Zero);
        var monthCheckins = checkins.Where(c => c.CreatedAt >= monthStart).ToList();
        var uniqueThisMonth = monthCheckins.Select(c => c.UserId).Distinct().Count();
        var employeeCount = ctx.EmployeeCount > 0
            ? ctx.EmployeeCount
            : checkins.Select(c => c.UserId).Distinct().Count();
        var participationRate = employeeCount > 0
            ? Math.Round((double)uniqueThisMonth / employeeCount, 4)
            : 0;

        var response = new WellbeingResponse(
            CompanyId:         ctx.CompanyId,
            CompanyName:       ctx.CompanyName,
            Score:             score,
            Dimensions:        dims,
            ParticipationRate: participationRate,
            RetentionRisk:     risk,
            EmployeeCount:     employeeCount,
            CheckinCount:      uniqueThisMonth,
            GeneratedAt:       DateTimeOffset.UtcNow
        );

        return Ok(response);
    }
}
