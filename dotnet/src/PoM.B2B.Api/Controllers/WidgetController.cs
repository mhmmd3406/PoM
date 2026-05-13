using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using PoM.B2B.Api.Models;
using PoM.B2B.Api.Services;

namespace PoM.B2B.Api.Controllers;

/// <summary>
/// DaaS (Data-as-a-Service) Public Widget API.
///
/// Authenticated via X-API-Key header (DaasAuthMiddleware).
/// Rate limited: fixed window 1 000 req/hour per API key (configurable per key).
///
/// Designed for embedding into external platforms (LinkedIn, Kariyer.net, etc.)
/// to display a simplified "PoM happiness score" badge.
/// </summary>
[ApiController]
[Route("api/widget")]
[EnableRateLimiting("DaasFixedWindow")]
public sealed class WidgetController(IFirestoreService firestore) : ControllerBase
{
    /// <summary>
    /// Returns simplified happiness scores for a bank + business family.
    ///
    /// When the bank+family cell has fewer than 7 entries the response sets
    /// IsObfuscated=true and all score fields are null — matching the privacy
    /// guarantee enforced across the rest of the platform.
    ///
    /// No Firebase token required — only an X-API-Key.
    /// </summary>
    [HttpGet("{bankId}/{businessFamily}")]
    [ProducesResponseType<WidgetResponse>(200)]
    [ProducesResponseType(401)]    // missing / invalid API key
    [ProducesResponseType(429)]    // rate limit exceeded
    public async Task<IActionResult> GetWidget(
        string bankId,
        string businessFamily = "all",
        CancellationToken ct = default)
    {
        // DaasAuthMiddleware already validated the key and populated DaasClaims
        if (HttpContext.Items["DaasClaims"] is not DaasClaims)
        {
            return Unauthorized(new { error = "invalid_api_key" });
        }

        // Sanitise path parameters — prevent Firestore collection traversal
        bankId         = SanitiseId(bankId);
        businessFamily = SanitiseId(businessFamily);

        if (string.IsNullOrEmpty(bankId))
            return BadRequest(new { error = "invalid_bank_id" });

        var result = await firestore.GetWidgetDataAsync(bankId, businessFamily, ct);
        return Ok(result);
    }

    private static string SanitiseId(string input) =>
        new string(input.Where(c => char.IsLetterOrDigit(c) || c == '_' || c == '-').ToArray())
            .ToLowerInvariant()[..Math.Min(input.Length, 64)];
}
