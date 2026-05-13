using Microsoft.AspNetCore.Mvc;
using PoM.B2B.Api.Models;
using PoM.B2B.Api.Services;

namespace PoM.B2B.Api.Controllers;

[ApiController]
[Route("api/benchmark")]
public sealed class BenchmarkController(IFirestoreService firestore) : ControllerBase
{
    private const int MaxCompetitors = 3;

    // ── Bank vs Sector ────────────────────────────────────────────────────────

    /// <summary>
    /// Compares the authenticated bank's snapshot against the sector average.
    /// Available to all B2B tiers.
    /// </summary>
    [HttpGet]
    [ProducesResponseType<BenchmarkResponse>(200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetBenchmark(
        [FromQuery] string businessFamily = "all",
        [FromQuery] int year  = 0,
        [FromQuery] int month = 0,
        CancellationToken ct = default)
    {
        var claims = GetClaims();
        if (year == 0)  year  = DateTimeOffset.UtcNow.Year;
        if (month == 0) month = DateTimeOffset.UtcNow.Month;

        var result = await firestore.GetBenchmarkAsync(claims.BankId, businessFamily, year, month, ct);
        return result is null ? NotFound(new { error = "no_snapshot_available" }) : Ok(result);
    }

    // ── Head-to-Head (Enterprise+) ────────────────────────────────────────────

    /// <summary>
    /// Compares the authenticated bank against up to 3 named competitors
    /// for a given business family and month.
    ///
    /// Enterprise tier required.
    /// N &lt; 7 invariant: competitor cells with insufficient data return
    /// IsObfuscated=true and null Metrics — enforced at the service layer.
    /// </summary>
    [HttpGet("head-to-head")]
    [ProducesResponseType<HeadToHeadResponse>(200)]
    [ProducesResponseType(400)]
    [ProducesResponseType(403)]
    public async Task<IActionResult> GetHeadToHead(
        [FromQuery(Name = "competitor")] List<string>? competitors,
        [FromQuery] string businessFamily = "all",
        [FromQuery] int year  = 0,
        [FromQuery] int month = 0,
        CancellationToken ct = default)
    {
        var claims = GetClaims();

        if (!claims.Tier.IsAtLeast(SubscriptionTier.Enterprise))
            return StatusCode(403, new { error = "enterprise_required", current_tier = claims.Tier.ToString() });

        competitors ??= [];
        if (competitors.Count == 0)
            return BadRequest(new { error = "at_least_one_competitor_required" });
        if (competitors.Count > MaxCompetitors)
            return BadRequest(new { error = $"max_{MaxCompetitors}_competitors_allowed" });
        if (competitors.Any(c => string.Equals(c, claims.BankId, StringComparison.OrdinalIgnoreCase)))
            return BadRequest(new { error = "cannot_compare_bank_with_itself" });

        if (year == 0)  year  = DateTimeOffset.UtcNow.Year;
        if (month == 0) month = DateTimeOffset.UtcNow.Month;

        var result = await firestore.GetHeadToHeadAsync(
            claims.BankId, competitors, businessFamily, year, month, ct);
        return Ok(result);
    }

    // ── Retention Risk (Enterprise+) ──────────────────────────────────────────

    /// <summary>
    /// Analyses the last N months of snapshots for every business family.
    /// Flags departments with a negative slope &gt; 0.1 points/month.
    ///
    /// Risk classification:
    ///   "high"     → slope &lt; -0.2 / month
    ///   "moderate" → slope &lt; -0.1 / month
    ///   "low"      → stable or improving
    ///
    /// Enterprise tier required.
    /// </summary>
    [HttpGet("retention-risk")]
    [ProducesResponseType<RetentionRiskResponse>(200)]
    [ProducesResponseType(403)]
    public async Task<IActionResult> GetRetentionRisk(
        [FromQuery] int months = 3,
        CancellationToken ct = default)
    {
        var claims = GetClaims();

        if (!claims.Tier.IsAtLeast(SubscriptionTier.Enterprise))
            return StatusCode(403, new { error = "enterprise_required", current_tier = claims.Tier.ToString() });

        months = Math.Clamp(months, 2, 12);
        var result = await firestore.GetRetentionRiskAsync(claims.BankId, months, ct);
        return Ok(result);
    }

    private B2BClaims GetClaims() =>
        HttpContext.Items["B2BClaims"] as B2BClaims
        ?? throw new InvalidOperationException("B2BClaims missing");
}
