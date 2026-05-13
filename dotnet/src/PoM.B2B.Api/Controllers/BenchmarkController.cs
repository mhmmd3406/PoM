using Microsoft.AspNetCore.Mvc;
using PoM.B2B.Api.Models;
using PoM.B2B.Api.Services;

namespace PoM.B2B.Api.Controllers;

[ApiController]
[Route("api/benchmark")]
public sealed class BenchmarkController(IFirestoreService firestore) : ControllerBase
{
    /// <summary>
    /// Compares the authenticated bank's snapshot scores against the sector
    /// average for a given month. Delta column shows where the bank leads or
    /// lags the market — the core value proposition for B2B subscribers.
    /// </summary>
    [HttpGet]
    [ProducesResponseType<BenchmarkResponse>(200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetBenchmark(
        [FromQuery] string businessFamily = "all",
        [FromQuery] int year  = 0,
        [FromQuery] int month = 0,
        CancellationToken ct  = default)
    {
        var claims = HttpContext.Items["B2BClaims"] as B2BClaims
            ?? throw new InvalidOperationException("B2BClaims missing");

        if (year == 0)  year  = DateTimeOffset.UtcNow.Year;
        if (month == 0) month = DateTimeOffset.UtcNow.Month;

        var result = await firestore.GetBenchmarkAsync(
            claims.BankId, businessFamily, year, month, ct);

        if (result is null)
            return NotFound(new { error = "no_snapshot_available" });

        return Ok(result);
    }
}
