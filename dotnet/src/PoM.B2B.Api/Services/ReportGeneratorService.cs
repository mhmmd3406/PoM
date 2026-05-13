using ClosedXML.Excel;
using PoM.B2B.Api.Models;

namespace PoM.B2B.Api.Services;

/// <summary>
/// Builds in-memory Excel or JSON reports from trend + benchmark data.
/// Completed reports are cached briefly in memory (production: use Azure Blob / GCS).
/// </summary>
public sealed class ReportGeneratorService(FirestoreService firestore)
{
    // In production this would be a distributed cache or object storage.
    // For the MVP, a thread-safe dict keyed by jobId is sufficient.
    private readonly Dictionary<string, ReportEntry> _cache = new();
    private readonly Lock _lock = new();

    public record ReportEntry(
        bool IsReady,
        byte[]? Bytes,
        string? ContentType,
        string? FileName);

    // Called by the Hangfire job — runs on background thread
    public async Task BuildReportAsync(
        string bankId,
        string jobId,
        ReportRequest request,
        CancellationToken ct)
    {
        // Mark as generating
        Store(jobId, new ReportEntry(false, null, null, null));

        try
        {
            var trend = await firestore.GetTrendAsync(
                bankId,
                request.BusinessFamily,
                request.FromYear, request.FromMonth,
                request.ToYear,   request.ToMonth,
                ct);

            var benchmark = await firestore.GetBenchmarkAsync(
                bankId,
                request.BusinessFamily,
                request.ToYear, request.ToMonth,
                ct);

            byte[] bytes;
            string contentType;
            string fileName;

            if (request.Format == ReportFormat.Excel)
            {
                (bytes, contentType, fileName) = BuildExcel(bankId, trend, benchmark, request);
            }
            else
            {
                var json = System.Text.Json.JsonSerializer.Serialize(new { trend, benchmark });
                bytes       = System.Text.Encoding.UTF8.GetBytes(json);
                contentType = "application/json";
                fileName    = $"pom_report_{bankId}_{jobId}.json";
            }

            Store(jobId, new ReportEntry(true, bytes, contentType, fileName));
        }
        catch
        {
            Store(jobId, new ReportEntry(false, null, null, null));
            throw;
        }
    }

    public Task<ReportEntry?> GetReportAsync(string bankId, string jobId, CancellationToken _)
    {
        lock (_lock)
        {
            _cache.TryGetValue(jobId, out var entry);
            return Task.FromResult(entry);
        }
    }

    // -------------------------------------------------------------------------
    // Excel builder
    // -------------------------------------------------------------------------

    private static (byte[] bytes, string contentType, string fileName) BuildExcel(
        string bankId,
        TrendResponse trend,
        BenchmarkResponse? benchmark,
        ReportRequest request)
    {
        using var wb = new XLWorkbook();

        BuildTrendSheet(wb, trend);
        if (benchmark is not null)
            BuildBenchmarkSheet(wb, benchmark);

        using var ms = new MemoryStream();
        wb.SaveAs(ms);

        var period = $"{request.FromYear}-{request.FromMonth:D2}_to_{request.ToYear}-{request.ToMonth:D2}";
        return (
            ms.ToArray(),
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            $"pom_report_{bankId}_{period}.xlsx");
    }

    private static void BuildTrendSheet(IXLWorkbook wb, TrendResponse trend)
    {
        var ws = wb.Worksheets.Add("Trend");
        StyleHeader(ws);

        // Headers
        string[] headers = ["Year", "Month", "Responses", "Salary", "Benefits",
                            "Work Model", "Culture", "WLB", "Overall", "Snapshot Date"];
        for (int i = 0; i < headers.Length; i++)
        {
            var cell = ws.Cell(1, i + 1);
            cell.Value = headers[i];
            cell.Style.Font.Bold = true;
            cell.Style.Fill.BackgroundColor = XLColor.FromHtml("#1A1A26");
            cell.Style.Font.FontColor = XLColor.White;
        }

        int row = 2;
        foreach (var p in trend.Points)
        {
            ws.Cell(row, 1).Value  = p.Year;
            ws.Cell(row, 2).Value  = p.Month;
            ws.Cell(row, 3).Value  = p.EntryCount;
            ws.Cell(row, 4).Value  = Math.Round(p.Averages.Salary,    2);
            ws.Cell(row, 5).Value  = Math.Round(p.Averages.Benefits,  2);
            ws.Cell(row, 6).Value  = Math.Round(p.Averages.WorkModel, 2);
            ws.Cell(row, 7).Value  = Math.Round(p.Averages.Culture,   2);
            ws.Cell(row, 8).Value  = Math.Round(p.Averages.Wlb,       2);
            ws.Cell(row, 9).Value  = Math.Round(p.Averages.Overall,   2);
            ws.Cell(row, 10).Value = p.SnapshotDate;

            // Colour-code Overall: red < 3, amber < 4, green >= 4
            var overallCell = ws.Cell(row, 9);
            overallCell.Style.Fill.BackgroundColor = p.Averages.Overall switch
            {
                >= 4.0 => XLColor.FromHtml("#D1FAE5"),
                >= 3.0 => XLColor.FromHtml("#FEF3C7"),
                _      => XLColor.FromHtml("#FEE2E2"),
            };

            row++;
        }

        ws.Columns().AdjustToContents();
    }

    private static void BuildBenchmarkSheet(IXLWorkbook wb, BenchmarkResponse benchmark)
    {
        var ws = wb.Worksheets.Add("Benchmark");
        StyleHeader(ws);

        // Meta row
        ws.Cell(1, 1).Value = $"Bank: {benchmark.BankId}   |   Period: {benchmark.Year}-{benchmark.Month:D2}   |   Responses: {benchmark.BankEntryCount}";
        ws.Cell(1, 1).Style.Font.Bold = true;
        ws.Range(1, 1, 1, 5).Merge();

        // Headers
        string[] headers = ["Metric", "Your Bank", "Sector Avg", "Delta", "Status"];
        for (int i = 0; i < headers.Length; i++)
        {
            var cell = ws.Cell(2, i + 1);
            cell.Value = headers[i];
            cell.Style.Font.Bold = true;
            cell.Style.Fill.BackgroundColor = XLColor.FromHtml("#1A1A26");
            cell.Style.Font.FontColor = XLColor.White;
        }

        int row = 3;
        foreach (var m in benchmark.Metrics)
        {
            ws.Cell(row, 1).Value = m.Name;
            ws.Cell(row, 2).Value = m.BankValue;
            ws.Cell(row, 3).Value = m.SectorValue.HasValue ? m.SectorValue.Value : "N/A";
            ws.Cell(row, 4).Value = m.Delta.HasValue ? m.Delta.Value : "N/A";

            if (m.Delta.HasValue)
            {
                var status = m.Delta.Value switch
                {
                    > 0.2  => "↑ Above market",
                    < -0.2 => "↓ Below market",
                    _      => "≈ At market",
                };
                ws.Cell(row, 5).Value = status;

                var deltaCell = ws.Cell(row, 4);
                deltaCell.Style.Fill.BackgroundColor = m.Delta.Value switch
                {
                    > 0.2  => XLColor.FromHtml("#D1FAE5"),
                    < -0.2 => XLColor.FromHtml("#FEE2E2"),
                    _      => XLColor.FromHtml("#FEF3C7"),
                };
            }

            row++;
        }

        ws.Columns().AdjustToContents();
    }

    private static void StyleHeader(IXLWorksheet ws)
    {
        ws.Style.Font.FontName = "Calibri";
        ws.Style.Font.FontSize = 11;
    }

    private void Store(string jobId, ReportEntry entry)
    {
        lock (_lock) { _cache[jobId] = entry; }
    }
}
