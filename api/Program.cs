using System.Text.Json;
using System.Text.Json.Serialization;
using Google.Cloud.Firestore;
using Microsoft.OpenApi.Models;
using PomApi.Middleware;
using PomApi.Services;

var builder = WebApplication.CreateBuilder(args);

// ---------------------------------------------------------------------------
// Firestore
// ---------------------------------------------------------------------------
var projectId = Environment.GetEnvironmentVariable("FIRESTORE_PROJECT_ID")
    ?? builder.Configuration["Firestore:ProjectId"]
    ?? throw new InvalidOperationException(
        "Firestore project ID must be set via FIRESTORE_PROJECT_ID env var or Firestore:ProjectId config.");

builder.Services.AddSingleton(_ => FirestoreDb.Create(projectId));
builder.Services.AddSingleton<FirestoreService>();
builder.Services.AddSingleton<ApiKeyService>();
builder.Services.AddSingleton<ThresholdService>();

// ---------------------------------------------------------------------------
// Controllers — camelCase JSON, enum as string
// ---------------------------------------------------------------------------
builder.Services.AddControllers()
    .AddJsonOptions(opts =>
    {
        opts.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        opts.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
        opts.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
    });

// Rate limiting is handled by RateLimitMiddleware (custom per-API-key sliding window).

// ---------------------------------------------------------------------------
// CORS
// ---------------------------------------------------------------------------
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>()
    ?? new[] { "https://dashboard.pom.app" };

builder.Services.AddCors(opts =>
{
    opts.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(allowedOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .WithExposedHeaders("X-RateLimit-Limit", "X-RateLimit-Remaining", "Retry-After");
    });
});

// ---------------------------------------------------------------------------
// Swagger / OpenAPI
// ---------------------------------------------------------------------------
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title   = "PoM B2B API",
        Version = "v1",
        Description = "Enterprise wellbeing data API for PoM (Peace of Mind) B2B customers.",
        Contact = new OpenApiContact { Email = "support@pom.app" }
    });

    c.AddSecurityDefinition("ApiKey", new OpenApiSecurityScheme
    {
        Type        = SecuritySchemeType.ApiKey,
        In          = ParameterLocation.Header,
        Name        = "X-Api-Key",
        Description = "B2B API key issued by PoM."
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "ApiKey" }
            },
            Array.Empty<string>()
        }
    });

    // Include XML doc comments if present
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
        c.IncludeXmlComments(xmlPath);
});

// ---------------------------------------------------------------------------
// Health checks
// ---------------------------------------------------------------------------
builder.Services.AddHealthChecks();

// ---------------------------------------------------------------------------
// Build pipeline
// ---------------------------------------------------------------------------
var app = builder.Build();

app.UseHealthChecks("/health");

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "PoM B2B API v1"));
}

app.UseCors();

// Rate-limit middleware (custom sliding window per API key string)
app.UseMiddleware<RateLimitMiddleware>();

// API key validation — populates CompanyContext
app.UseMiddleware<ApiKeyMiddleware>();

app.MapControllers();

app.Run();
