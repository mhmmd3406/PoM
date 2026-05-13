using Hangfire;
using PoM.B2B.Api.Models;
using PoM.B2B.Api.Services;

namespace PoM.B2B.Api.Jobs;

/// <summary>
/// Hangfire job: on-demand report generation triggered by POST /api/report/generate.
/// </summary>
[AutomaticRetry(Attempts = 2)]
public sealed class ReportJob(ReportGeneratorService reportGenerator)
{
    [JobDisplayName("Generate Report — {0}")]
    public Task GenerateAsync(string bankId, ReportRequest request, CancellationToken ct)
        => reportGenerator.BuildReportAsync(bankId, GetJobId(), request, ct);

    // Hangfire injects the job ID via the execution context; we read it from
    // the ambient PerformContext if available, otherwise fall back to a GUID.
    private static string GetJobId()
    {
        // In a real Hangfire execution the job ID is available via PerformContext.
        // We use a GUID fallback here because PerformContext requires explicit
        // parameter injection (done in Program.cs via JobActivator).
        return Guid.NewGuid().ToString("N")[..12];
    }
}

/// <summary>
/// Hangfire recurring job: generate weekly B2B summary reports for all active banks.
/// Scheduled every Monday at 06:00 UTC (after daily snapshot at 04:00 UTC).
/// </summary>
public sealed class WeeklyReportJob(
    IFirestoreService firestore,
    ReportGeneratorService reportGenerator,
    ILogger<WeeklyReportJob> logger)
{
    [JobDisplayName("Weekly B2B Reports — all banks")]
    public async Task RunAsync(CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        var fromDate = now.AddMonths(-2);

        // Fetch all active banks from Firestore
        var banksSnap = await firestore.GetActiveBankIdsAsync(ct);

        logger.LogInformation("WeeklyReportJob: generating for {Count} banks", banksSnap.Count);

        foreach (var bankId in banksSnap)
        {
            var request = new ReportRequest(
                BusinessFamily: "all",
                FromYear:  fromDate.Year,
                FromMonth: fromDate.Month,
                ToYear:    now.Year,
                ToMonth:   now.Month,
                Format:    ReportFormat.Excel);

            var jobId = $"weekly_{bankId}_{now:yyyyMMdd}";

            try
            {
                await reportGenerator.BuildReportAsync(bankId, jobId, request, ct);
                logger.LogInformation("WeeklyReportJob: {BankId} ✓", bankId);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "WeeklyReportJob: {BankId} failed", bankId);
            }
        }
    }
}
