using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using PoM.B2B.Api.Controllers;
using PoM.B2B.Api.Models;
using PoM.B2B.Api.Services;
using Xunit;

namespace PoM.B2B.Api.Tests;

/// <summary>
/// Tests controller input-validation logic without spinning up the full ASP.NET pipeline.
/// B2BClaims are injected via HttpContext.Items, which is how B2BAuthMiddleware populates them.
/// </summary>
public sealed class ControllerValidationTests
{
    private static HttpContext MakeContext(string bankId = "test-bank")
    {
        var ctx = new DefaultHttpContext();
        ctx.Items["B2BClaims"] = new B2BClaims(bankId, "admin@bank.com");
        return ctx;
    }

    // ── TrendController ────────────────────────────────────────────────────────

    [Fact]
    public async Task Trend_FromYearAfterToYear_ReturnsBadRequest()
    {
        var ctrl = new TrendController(new Mock<IFirestoreService>().Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        var result = await ctrl.GetTrend(
            businessFamily: "all",
            fromYear: 2025, fromMonth: 1,
            toYear:   2024, toMonth:   12);

        var bad = Assert.IsType<BadRequestObjectResult>(result);
        Assert.Contains("invalid_date_range", bad.Value?.ToString());
    }

    [Fact]
    public async Task Trend_SameYearFromMonthAfterToMonth_ReturnsBadRequest()
    {
        var ctrl = new TrendController(new Mock<IFirestoreService>().Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        var result = await ctrl.GetTrend(
            fromYear: 2024, fromMonth: 8,
            toYear:   2024, toMonth:   5);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task Trend_ValidRange_ReturnsOk()
    {
        var expected = new TrendResponse("test-bank", "all", []);
        var firestore = new Mock<IFirestoreService>();
        firestore.Setup(f => f.GetTrendAsync("test-bank", "all", 2024, 1, 2024, 12, default))
                 .ReturnsAsync(expected);

        var ctrl = new TrendController(firestore.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        var result = await ctrl.GetTrend(
            fromYear: 2024, fromMonth: 1,
            toYear:   2024, toMonth:   12);

        var ok = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(expected, ok.Value);
    }

    // ── BenchmarkController ────────────────────────────────────────────────────

    [Fact]
    public async Task Benchmark_NoSnapshot_ReturnsNotFound()
    {
        var firestore = new Mock<IFirestoreService>();
        firestore.Setup(f => f.GetBenchmarkAsync("test-bank", "all", It.IsAny<int>(), It.IsAny<int>(), default))
                 .ReturnsAsync((BenchmarkResponse?)null);

        var ctrl = new BenchmarkController(firestore.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        var result = await ctrl.GetBenchmark();

        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Fact]
    public async Task Benchmark_SnapshotExists_ReturnsOk()
    {
        var expected = new BenchmarkResponse(
            "test-bank", "all", 2024, 11, 20,
            [new BenchmarkMetric("Salary", 3.5, 3.2, 0.3)]);

        var firestore = new Mock<IFirestoreService>();
        firestore.Setup(f => f.GetBenchmarkAsync("test-bank", "all", It.IsAny<int>(), It.IsAny<int>(), default))
                 .ReturnsAsync(expected);

        var ctrl = new BenchmarkController(firestore.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        var result = await ctrl.GetBenchmark();

        var ok = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(expected, ok.Value);
    }
}
