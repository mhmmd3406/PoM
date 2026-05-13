using Hangfire;
using Microsoft.AspNetCore.Mvc;
using PoM.B2B.Api.Jobs;
using PoM.B2B.Api.Models;
using PoM.B2B.Api.Services;

namespace PoM.B2B.Api.Controllers;

[ApiController]
[Route("api/report")]
public sealed class ReportController(
    IBackgroundJobClient jobClient,
    ReportGeneratorService reportGenerator) : ControllerBase
{
    /// <summary>
    /// Enqueues an on-demand report generation job.
    /// Returns a job ID immediately; poll /api/report/{jobId}/status for readiness.
    /// </summary>
    [HttpPost("generate")]
    [ProducesResponseType<ReportStatus>(202)]
    [ProducesResponseType(400)]
    public IActionResult GenerateReport([FromBody] ReportRequest request)
    {
        var claims = HttpContext.Items["B2BClaims"] as B2BClaims
            ?? throw new InvalidOperationException("B2BClaims missing");

        if (request.FromYear > request.ToYear ||
            (request.FromYear == request.ToYear && request.FromMonth > request.ToMonth))
            return BadRequest(new { error = "invalid_date_range" });

        var jobId = jobClient.Enqueue<ReportJob>(
            job => job.GenerateAsync(claims.BankId, request, CancellationToken.None));

        return Accepted(new ReportStatus(
            ReportId:    jobId,
            Status:      "queued",
            DownloadUrl: null,
            GeneratedAt: null));
    }

    /// <summary>
    /// Downloads a completed report.
    /// Returns 202 if still generating, 404 if job unknown.
    /// </summary>
    [HttpGet("{jobId}/download")]
    public async Task<IActionResult> Download(string jobId, CancellationToken ct)
    {
        var claims = HttpContext.Items["B2BClaims"] as B2BClaims
            ?? throw new InvalidOperationException("B2BClaims missing");

        var result = await reportGenerator.GetReportAsync(claims.BankId, jobId, ct);

        return result switch
        {
            null                           => NotFound(new { error = "report_not_found" }),
            { IsReady: false }             => StatusCode(202, new ReportStatus(jobId, "generating", null, null)),
            { IsReady: true, Bytes: var b, ContentType: var ct2, FileName: var fn }
                => File(b!, ct2!, fn!),
        };
    }
}
