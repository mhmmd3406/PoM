using FirebaseAdmin.Auth;
using PoM.B2B.Api.Models;

namespace PoM.B2B.Api.Middleware;

/// <summary>
/// Validates Firebase ID tokens, enforces the b2b_bank_id custom claim,
/// and extracts the subscription_tier claim for downstream RBAC checks.
///
/// Populates HttpContext.Items["B2BClaims"] so controllers receive a typed
/// B2BClaims record without repeating claim extraction.
/// </summary>
public sealed class B2BAuthMiddleware(RequestDelegate next)
{
    private static readonly string[] _publicPaths =
        ["/health", "/swagger", "/swagger/v1/swagger.json", "/api/widget"];

    public async Task InvokeAsync(HttpContext context)
    {
        // Skip auth for health-check, Swagger, and the DaaS Widget endpoint
        // (Widget uses its own DaasAuthMiddleware via API key)
        if (_publicPaths.Any(p => context.Request.Path.StartsWithSegments(p)))
        {
            await next(context);
            return;
        }

        var authHeader = context.Request.Headers.Authorization.FirstOrDefault();
        if (authHeader is null || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new { error = "missing_token" });
            return;
        }

        var idToken = authHeader["Bearer ".Length..].Trim();

        FirebaseToken decoded;
        try
        {
            decoded = await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(idToken);
        }
        catch (FirebaseAuthException)
        {
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new { error = "invalid_token" });
            return;
        }

        // B2B custom claim — set server-side during B2B onboarding
        if (!decoded.Claims.TryGetValue("b2b_bank_id", out var bankIdObj)
            || bankIdObj is not string bankId
            || string.IsNullOrEmpty(bankId))
        {
            context.Response.StatusCode = 403;
            await context.Response.WriteAsJsonAsync(new { error = "b2b_access_only" });
            return;
        }

        // subscription_tier custom claim — set by Cloud Function onUserSubscriptionChanged.
        // B2B users without an explicit tier default to Enterprise (they're paying customers).
        var tierRaw = decoded.Claims.TryGetValue("subscription_tier", out var tierObj)
            ? tierObj?.ToString()
            : "enterprise";

        var tier  = SubscriptionTierExtensions.Parse(tierRaw);
        var email = decoded.Claims.TryGetValue("email", out var e) ? e?.ToString() ?? "" : "";

        context.Items["B2BClaims"] = new B2BClaims(bankId, email, tier);

        await next(context);
    }
}

public static class B2BAuthMiddlewareExtensions
{
    public static IApplicationBuilder UseB2BAuth(this IApplicationBuilder app)
        => app.UseMiddleware<B2BAuthMiddleware>();
}
