using FirebaseAdmin.Auth;
using PoM.B2B.Api.Models;

namespace PoM.B2B.Api.Middleware;

/// <summary>
/// Validates Firebase ID tokens on every request and enforces that the caller
/// carries a `b2b_bank_id` custom claim set during B2B onboarding.
///
/// Populates HttpContext.Items["B2BClaims"] so controllers don't repeat the
/// claim extraction logic.
/// </summary>
public sealed class B2BAuthMiddleware(RequestDelegate next)
{
    private static readonly string[] _publicPaths =
        ["/health", "/swagger", "/swagger/v1/swagger.json"];

    public async Task InvokeAsync(HttpContext context)
    {
        // Skip auth for health-check and Swagger UI
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

        // Enforce B2B custom claim — set server-side during B2B onboarding
        if (!decoded.Claims.TryGetValue("b2b_bank_id", out var bankIdObj)
            || bankIdObj is not string bankId
            || string.IsNullOrEmpty(bankId))
        {
            context.Response.StatusCode = 403;
            await context.Response.WriteAsJsonAsync(new { error = "b2b_access_only" });
            return;
        }

        var email = decoded.Claims.TryGetValue("email", out var e) ? e?.ToString() ?? "" : "";
        context.Items["B2BClaims"] = new B2BClaims(bankId, email);

        await next(context);
    }
}

// Extension for clean registration in Program.cs
public static class B2BAuthMiddlewareExtensions
{
    public static IApplicationBuilder UseB2BAuth(this IApplicationBuilder app)
        => app.UseMiddleware<B2BAuthMiddleware>();
}
