using Moq;
using PoM.B2B.Api.Models;
using PoM.B2B.Api.Services;
using Xunit;

namespace PoM.B2B.Api.Tests;

public sealed class ReportGeneratorServiceTests
{
    private static readonly MetricAverages SampleAverages = new(3.5, 4.0, 3.8, 4.2, 3.9, 3.88);

    private static TrendResponse MakeTrend(string bankId) => new(
        bankId, "all",
        [
            new TrendPoint(2024, 10, 12, "2024-10-31", SampleAverages),
            new TrendPoint(2024, 11, 15, "2024-11-30", SampleAverages),
        ]);

    private static BenchmarkResponse MakeBenchmark(string bankId) => new(
        bankId, "all", 2024, 11, 15,
        [
            new BenchmarkMetric("Salary",    3.5, 3.2, 0.3),
            new BenchmarkMetric("Benefits",  4.0, 4.1, -0.1),
            new BenchmarkMetric("Overall",   3.88, 3.6, 0.28),
        ]);

    [Fact]
    public async Task BuildReportAsync_Json_StoresReadyEntry()
    {
        var firestore = new Mock<IFirestoreService>();
        firestore.Setup(f => f.GetTrendAsync("bank1", "all", 2024, 10, 2024, 11, default))
                 .ReturnsAsync(MakeTrend("bank1"));
        firestore.Setup(f => f.GetBenchmarkAsync("bank1", "all", 2024, 11, default))
                 .ReturnsAsync(MakeBenchmark("bank1"));

        var svc = new ReportGeneratorService(firestore.Object);
        var req = new ReportRequest("all", 2024, 10, 2024, 11, ReportFormat.Json);

        await svc.BuildReportAsync("bank1", "job-001", req, CancellationToken.None);
        var entry = await svc.GetReportAsync("bank1", "job-001", CancellationToken.None);

        Assert.NotNull(entry);
        Assert.True(entry.IsReady);
        Assert.NotNull(entry.Bytes);
        Assert.Equal("application/json", entry.ContentType);
        Assert.Contains("bank1", entry.FileName);
    }

    [Fact]
    public async Task BuildReportAsync_Excel_ProducesValidXlsx()
    {
        var firestore = new Mock<IFirestoreService>();
        firestore.Setup(f => f.GetTrendAsync("bank1", "all", 2024, 10, 2024, 11, default))
                 .ReturnsAsync(MakeTrend("bank1"));
        firestore.Setup(f => f.GetBenchmarkAsync("bank1", "all", 2024, 11, default))
                 .ReturnsAsync(MakeBenchmark("bank1"));

        var svc = new ReportGeneratorService(firestore.Object);
        var req = new ReportRequest("all", 2024, 10, 2024, 11, ReportFormat.Excel);

        await svc.BuildReportAsync("bank1", "job-002", req, CancellationToken.None);
        var entry = await svc.GetReportAsync("bank1", "job-002", CancellationToken.None);

        Assert.NotNull(entry);
        Assert.True(entry.IsReady);
        Assert.Equal(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            entry.ContentType);
        Assert.EndsWith(".xlsx", entry.FileName);
        // XLSX magic bytes: PK zip header
        Assert.Equal(0x50, entry.Bytes![0]);
        Assert.Equal(0x4B, entry.Bytes![1]);
    }

    [Fact]
    public async Task GetReportAsync_UnknownJob_ReturnsNull()
    {
        var svc = new ReportGeneratorService(new Mock<IFirestoreService>().Object);
        var entry = await svc.GetReportAsync("bank1", "no-such-job", CancellationToken.None);
        Assert.Null(entry);
    }

    [Fact]
    public async Task BuildReportAsync_NoBenchmark_ExcelStillSucceeds()
    {
        var firestore = new Mock<IFirestoreService>();
        firestore.Setup(f => f.GetTrendAsync("bank2", "IT", 2024, 1, 2024, 3, default))
                 .ReturnsAsync(MakeTrend("bank2"));
        firestore.Setup(f => f.GetBenchmarkAsync("bank2", "IT", 2024, 3, default))
                 .ReturnsAsync((BenchmarkResponse?)null);

        var svc = new ReportGeneratorService(firestore.Object);
        var req = new ReportRequest("IT", 2024, 1, 2024, 3, ReportFormat.Excel);

        await svc.BuildReportAsync("bank2", "job-003", req, CancellationToken.None);
        var entry = await svc.GetReportAsync("bank2", "job-003", CancellationToken.None);

        Assert.NotNull(entry);
        Assert.True(entry.IsReady);
    }
}
