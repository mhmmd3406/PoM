using Google.Cloud.Firestore;
using PoM.B2B.Api.Models;

namespace PoM.B2B.Api.Middleware;

/// <summary>
/// Authenticates DaaS (Widget API) requests via X-API-Key header.
/// Looks up the key hash in the api_keys Firestore collection.
/// Populates HttpContext.Items["DaasClaims"] on success.
///
/// This middleware only runs on /api/widget/** paths.
/// </summary>
public sealed class DaasAuthMiddleware(RequestDelegate next, IConfiguration config)
{
    private static readonly System.Security.Cryptography.SHA256 _sha256
        = System.Security.Cryptography.SHA256.Create();

    public async Task InvokeAsync(HttpContext context)
    {
        // Only intercept Widget API paths
        if (!context.Request.Path.StartsWithSegments("/api/widget"))
        {
            await next(context);
            return;
        }

        var apiKey = context.Request.Headers["X-API-Key"].FirstOrDefault();
        if (string.IsNullOrEmpty(apiKey))
        {
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new { error = "missing_api_key" });
            return;
        }

        // Hash the incoming key — we only store HMAC/SHA256 hashes, never plaintext
        var keyHash = HashApiKey(apiKey);

        var projectId = config["Firebase:ProjectId"]
            ?? throw new InvalidOperationException("Firebase:ProjectId not configured");

        var db = FirestoreDb.Create(projectId);
        var snap = await db.Collection("api_keys")
            .WhereEqualTo("key_hash", keyHash)
            .WhereEqualTo("is_active", true)
            .Limit(1)
            .GetSnapshotAsync();

        if (snap.Count == 0)
        {
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new { error = "invalid_api_key" });
            return;
        }

        var keyDoc  = snap.Documents[0];
        var bankId  = keyDoc.GetValue<string>("owner_bank_id");
        var rateLimit = keyDoc.ContainsField("rate_limit_per_hour")
            ? (int)keyDoc.GetValue<long>("rate_limit_per_hour")
            : 1000;

        context.Items["DaasClaims"] = new DaasClaims(keyDoc.Id, bankId, rateLimit);

        await next(context);
    }

    private static string HashApiKey(string key)
    {
        var bytes = System.Text.Encoding.UTF8.GetBytes(key);
        var hash  = _sha256.ComputeHash(bytes);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}

public static class DaasAuthMiddlewareExtensions
{
    public static IApplicationBuilder UseDaasAuth(this IApplicationBuilder app)
        => app.UseMiddleware<DaasAuthMiddleware>();
}
