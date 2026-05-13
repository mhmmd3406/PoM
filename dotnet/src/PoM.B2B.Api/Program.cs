using System.Threading.RateLimiting;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Hangfire;
using Hangfire.InMemory;
using PoM.B2B.Api.Jobs;
using PoM.B2B.Api.Middleware;
using PoM.B2B.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// -------------------------------------------------------------------------
// Firebase Admin SDK
// -------------------------------------------------------------------------
FirebaseApp.Create(new AppOptions
{
    Credential = GoogleCredential.GetApplicationDefault(),
    ProjectId  = builder.Configuration["Firebase:ProjectId"],
});

// -------------------------------------------------------------------------
// Services
// -------------------------------------------------------------------------
builder.Services.AddSingleton<IFirestoreService, FirestoreService>();
builder.Services.AddSingleton<ReportGeneratorService>();
builder.Services.AddScoped<ReportJob>();
builder.Services.AddScoped<WeeklyReportJob>();

builder.Services.AddControllers()
    .AddJsonOptions(o =>
    {
        o.JsonSerializerOptions.PropertyNamingPolicy =
            System.Text.Json.JsonNamingPolicy.CamelCase;
        o.JsonSerializerOptions.DefaultIgnoreCondition =
            System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull;
    });

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "PoM B2B API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new()
    {
        Name        = "Authorization",
        In          = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Type        = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme      = "bearer",
        Description = "Firebase ID Token (B2B) or X-API-Key (Widget)",
    });
    c.AddSecurityRequirement(new()
    {
        [new() { Reference = new() { Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme, Id = "Bearer" } }] = []
    });
});

// -------------------------------------------------------------------------
// Hangfire
// -------------------------------------------------------------------------
builder.Services.AddHangfire(cfg => cfg.UseInMemoryStorage());
builder.Services.AddHangfireServer();

// -------------------------------------------------------------------------
// CORS
// -------------------------------------------------------------------------
builder.Services.AddCors(o => o.AddPolicy("B2BPortal", p =>
    p.WithOrigins(builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? [])
     .AllowAnyHeader()
     .AllowAnyMethod()));

// -------------------------------------------------------------------------
// Rate Limiting — DaaS Widget API (built-in .NET 8, no extra package)
//
// Partitioned by X-API-Key so each DaaS customer has an independent bucket.
// Default: 1 000 requests per sliding hour.
// Per-key overrides are enforced in WidgetController after DaasAuthMiddleware
// resolves the key and its configured rate_limit_per_hour.
// -------------------------------------------------------------------------
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.AddPolicy("DaasFixedWindow", httpContext =>
    {
        var apiKey = httpContext.Request.Headers["X-API-Key"].FirstOrDefault() ?? "anonymous";

        // Use per-key limit if DaasClaims already resolved (middleware runs before controller)
        var limit = httpContext.Items["DaasClaims"] is PoM.B2B.Api.Models.DaasClaims claims
            ? claims.RateLimitPerHour
            : 100; // unauthenticated fallback (will be rejected by DaasAuthMiddleware anyway)

        return RateLimitPartition.GetFixedWindowLimiter(apiKey, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit          = limit,
            Window               = TimeSpan.FromHours(1),
            QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
            QueueLimit           = 0,
        });
    });
});

// -------------------------------------------------------------------------
// Stripe
// -------------------------------------------------------------------------
Stripe.StripeConfiguration.ApiKey = builder.Configuration["Stripe:SecretKey"];

// -------------------------------------------------------------------------
// Build
// -------------------------------------------------------------------------
var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("B2BPortal");

// DaaS auth must run before B2BAuth so Widget paths are handled separately
app.UseDaasAuth();
app.UseB2BAuth();

// Rate limiting must be registered before controllers
app.UseRateLimiter();

app.MapControllers();
app.MapGet("/health", () => Results.Ok(new { status = "healthy", utc = DateTimeOffset.UtcNow }))
   .ExcludeFromDescription();

app.UseHangfireDashboard("/hangfire", new DashboardOptions
{
    Authorization = [],
});

RecurringJob.AddOrUpdate<WeeklyReportJob>(
    "weekly-b2b-reports",
    job => job.RunAsync(CancellationToken.None),
    "0 6 * * MON",
    new RecurringJobOptions { TimeZone = TimeZoneInfo.Utc });

app.Run();
