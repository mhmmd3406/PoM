using Microsoft.AspNetCore.Mvc;
using PomApi.Middleware;
using PomApi.Models;
using PomApi.Services;

namespace PomApi.Controllers;

[ApiController]
[Route("api/v1")]
[Produces("application/json")]
public sealed class TrendsController : ControllerBase
{
    private readonly FirestoreService _firestore;

    public TrendsController(FirestoreService firestore)
    {
        _firestore = firestore;
    }

    /// <summary>
    /// Returns weekly trend data for the specified number of days (default 90, max 365).
    /// </summary>
    /// <param name="days">Lookback window in days (1–365).</param>
    /// <response code="200">Trend data returned successfully.</response>
    [HttpGet("trends")]
    [ProducesResponseType(typeof(TrendResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetTrends([FromQuery] int days = 90)
    {
        days = Math.Clamp(days, 1, 365);

        var ctx = ApiKeyMiddleware.GetCompanyContext(HttpContext);
        var checkins = await _firestore.GetCompanyCheckinsAsync(ctx.CompanyId);

        var points = InsightsAggregator.BuildTrendPoints(checkins, days);

        return Ok(new TrendResponse(
            CompanyId: ctx.CompanyId,
            Days:      days,
            Points:    points
        ));
    }
}
