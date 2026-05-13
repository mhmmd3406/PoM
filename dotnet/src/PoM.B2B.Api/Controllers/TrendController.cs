using Microsoft.AspNetCore.Mvc;
using PoM.B2B.Api.Models;
using PoM.B2B.Api.Services;

namespace PoM.B2B.Api.Controllers;

[ApiController]
[Route("api/trend")]
public sealed class TrendController(IFirestoreService firestore) : ControllerBase
{
    /// <summary>
    /// Month-over-month happiness trend for the authenticated bank.
    /// Data comes from differential-privacy-safe snapshots (delta >= 3).
    /// </summary>
    [HttpGet]
    [ProducesResponseType<TrendResponse>(200)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> GetTrend(
        [FromQuery] string businessFamily = "all",
        [FromQuery] int fromYear  = 0,
        [FromQuery] int fromMonth = 1,
        [FromQuery] int toYear    = 0,
        [FromQuery] int toMonth   = 12,
        CancellationToken ct = default)
    {
        var claims = HttpContext.Items["B2BClaims"] as B2BClaims
            ?? throw new InvalidOperationException("B2BClaims missing");

        // Default range: last 12 months
        if (fromYear == 0)
        {
            var now = DateTimeOffset.UtcNow;
            var start = now.AddMonths(-11);
            fromYear  = start.Year;
            fromMonth = start.Month;
            toYear    = now.Year;
            toMonth   = now.Month;
        }

        if (fromYear > toYear || (fromYear == toYear && fromMonth > toMonth))
            return BadRequest(new { error = "invalid_date_range" });

        var result = await firestore.GetTrendAsync(
            claims.BankId, businessFamily,
            fromYear, fromMonth, toYear, toMonth, ct);

        return Ok(result);
    }
}
