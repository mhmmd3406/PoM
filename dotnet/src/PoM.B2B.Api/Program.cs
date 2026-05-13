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
// Credentials: GOOGLE_APPLICATION_CREDENTIALS env var (service account JSON)
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
        Description = "Firebase ID Token",
    });
    c.AddSecurityRequirement(new()
    {
        [new() { Reference = new() { Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme, Id = "Bearer" } }] = []
    });
});

// -------------------------------------------------------------------------
// Hangfire
// Production: replace InMemory with Hangfire.SqlServer or Hangfire.Redis
// -------------------------------------------------------------------------
builder.Services.AddHangfire(config =>
    config.UseInMemoryStorage());
builder.Services.AddHangfireServer();

// -------------------------------------------------------------------------
// CORS (B2B portal SPA or ASP.NET Razor)
// -------------------------------------------------------------------------
builder.Services.AddCors(o => o.AddPolicy("B2BPortal", p =>
    p.WithOrigins(builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? [])
     .AllowAnyHeader()
     .AllowAnyMethod()));

var app = builder.Build();

// -------------------------------------------------------------------------
// Middleware pipeline
// -------------------------------------------------------------------------
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("B2BPortal");

// Firebase token + B2B claim enforcement (before controllers)
app.UseB2BAuth();

app.MapControllers();
app.MapGet("/health", () => Results.Ok(new { status = "healthy", utc = DateTimeOffset.UtcNow }))
   .ExcludeFromDescription();

// -------------------------------------------------------------------------
// Hangfire dashboard (internal only — restrict in production)
// -------------------------------------------------------------------------
app.UseHangfireDashboard("/hangfire", new DashboardOptions
{
    // In production, add an authorization filter here
    Authorization = [],
});

// Register weekly recurring job — every Monday 06:00 UTC
RecurringJob.AddOrUpdate<WeeklyReportJob>(
    "weekly-b2b-reports",
    job => job.RunAsync(CancellationToken.None),
    "0 6 * * MON",
    new RecurringJobOptions { TimeZone = TimeZoneInfo.Utc });

app.Run();
