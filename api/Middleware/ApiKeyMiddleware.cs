using PomApi.Models;
using PomApi.Services;

namespace PomApi.Middleware;

/// <summary>
/// Validates the <c>X-Api-Key</c> request header against Firestore.
/// Attaches a <see cref="CompanyContext"/> to <c>HttpContext.Items</c> on success.
/// Returns 401 for missing / invalid keys.
/// </summary>
public sealed class ApiKeyMiddleware
{
    private const string HeaderName = "X-Api-Key";
    private const string ContextKey = "CompanyContext";

    private readonly RequestDelegate _next;
    private readonly ILogger<ApiKeyMiddleware> _logger;

    public ApiKeyMiddleware(RequestDelegate next, ILogger<ApiKeyMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, ApiKeyService apiKeyService)
    {
        // Skip Swagger / health endpoints
        var path = context.Request.Path.Value ?? string.Empty;
        if (path.StartsWith("/swagger", StringComparison.OrdinalIgnoreCase) ||
            path.StartsWith("/health", StringComparison.OrdinalIgnoreCase))
        {
            await _next(context);
            return;
        }

        if (!context.Request.Headers.TryGetValue(HeaderName, out var rawKey) ||
            string.IsNullOrWhiteSpace(rawKey))
        {
            _logger.LogWarning("Request missing {Header} header: {Path}", HeaderName, path);
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new { error = "API anahtarı gereklidir. X-Api-Key başlığını ekleyin." });
            return;
        }

        var record = await apiKeyService.ValidateAsync(rawKey!);
        if (record is null)
        {
            _logger.LogWarning("Invalid API key presented for path {Path}", path);
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new { error = "Geçersiz veya deaktif API anahtarı." });
            return;
        }

        // Attach company context for downstream handlers
        context.Items[ContextKey] = new CompanyContext(
            CompanyId:    record.CompanyId,
            CompanyName:  record.CompanyName,
            IndustryName: record.IndustryName,
            EmployeeCount: record.EmployeeCount
        );

        await _next(context);
    }

    /// <summary>Extension method controllers can use to read the company context.</summary>
    public static CompanyContext GetCompanyContext(HttpContext context)
    {
        if (context.Items.TryGetValue(ContextKey, out var obj) && obj is CompanyContext ctx)
            return ctx;
        throw new InvalidOperationException("CompanyContext not found — ApiKeyMiddleware not registered?");
    }
}
