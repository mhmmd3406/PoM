using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using PoM.B2B.Api.Controllers;
using PoM.B2B.Api.Models;
using PoM.B2B.Api.Services;
using Xunit;

namespace PoM.B2B.Api.Tests;

/// <summary>
/// Tests controller input-validation and RBAC logic without spinning up the full
/// ASP.NET pipeline. B2BClaims are injected via HttpContext.Items, mirroring
/// B2BAuthMiddleware behaviour.
/// </summary>
public sealed class ControllerValidationTests
{
    // Helper: create an HttpContext with a given bank and subscription tier.
    private static HttpContext MakeContext(
        string bankId = "test-bank",
        SubscriptionTier tier = SubscriptionTier.Enterprise)
    {
        var ctx = new DefaultHttpContext();
        ctx.Items["B2BClaims"] = new B2BClaims(bankId, "admin@bank.com", tier);
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
        firestore
            .Setup(f => f.GetTrendAsync("test-bank", "all", 2024, 1, 2024, 12, default))
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

    // ── BenchmarkController — basic ────────────────────────────────────────────

    [Fact]
    public async Task Benchmark_NoSnapshot_ReturnsNotFound()
    {
        var firestore = new Mock<IFirestoreService>();
        firestore
            .Setup(f => f.GetBenchmarkAsync("test-bank", "all",
                It.IsAny<int>(), It.IsAny<int>(), default))
            .ReturnsAsync((BenchmarkResponse?)null);

        var ctrl = new BenchmarkController(firestore.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        Assert.IsType<NotFoundObjectResult>(await ctrl.GetBenchmark());
    }

    [Fact]
    public async Task Benchmark_SnapshotExists_ReturnsOk()
    {
        var expected = new BenchmarkResponse(
            "test-bank", "all", 2024, 11, 20,
            [new BenchmarkMetric("Salary", 3.5, 3.2, 0.3)]);

        var firestore = new Mock<IFirestoreService>();
        firestore
            .Setup(f => f.GetBenchmarkAsync("test-bank", "all",
                It.IsAny<int>(), It.IsAny<int>(), default))
            .ReturnsAsync(expected);

        var ctrl = new BenchmarkController(firestore.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        var ok = Assert.IsType<OkObjectResult>(await ctrl.GetBenchmark());
        Assert.Equal(expected, ok.Value);
    }

    // ── BenchmarkController — Head-to-Head RBAC ────────────────────────────────

    [Fact]
    public async Task HeadToHead_FreeTierUser_Returns403()
    {
        var ctrl = new BenchmarkController(new Mock<IFirestoreService>().Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = MakeContext(tier: SubscriptionTier.Free)
            }
        };

        var result = await ctrl.GetHeadToHead(
            competitors: ["other-bank"],
            businessFamily: "all");

        Assert.Equal(403, (result as ObjectResult)?.StatusCode);
    }

    [Fact]
    public async Task HeadToHead_ProTierUser_Returns403()
    {
        var ctrl = new BenchmarkController(new Mock<IFirestoreService>().Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = MakeContext(tier: SubscriptionTier.Pro)
            }
        };

        var result = await ctrl.GetHeadToHead(
            competitors: ["other-bank"],
            businessFamily: "all");

        Assert.Equal(403, (result as ObjectResult)?.StatusCode);
    }

    [Fact]
    public async Task HeadToHead_NoCompetitors_ReturnsBadRequest()
    {
        var ctrl = new BenchmarkController(new Mock<IFirestoreService>().Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        Assert.IsType<BadRequestObjectResult>(
            await ctrl.GetHeadToHead(competitors: [], businessFamily: "all"));
    }

    [Fact]
    public async Task HeadToHead_TooManyCompetitors_ReturnsBadRequest()
    {
        var ctrl = new BenchmarkController(new Mock<IFirestoreService>().Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        var result = await ctrl.GetHeadToHead(
            competitors: ["bank1", "bank2", "bank3", "bank4"], // 4 > max 3
            businessFamily: "all");

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task HeadToHead_CompetitorIsSelf_ReturnsBadRequest()
    {
        var ctrl = new BenchmarkController(new Mock<IFirestoreService>().Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = MakeContext(bankId: "my-bank")
            }
        };

        var result = await ctrl.GetHeadToHead(
            competitors: ["my-bank"],
            businessFamily: "all");

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task HeadToHead_EnterpriseTier_ValidRequest_ReturnsOk()
    {
        var expected = new HeadToHeadResponse(
            "all", 2026, 5,
            new HeadToHeadEntry("test-bank", false, 12, []),
            [new HeadToHeadEntry("rival-bank", false, 10, [])]);

        var firestore = new Mock<IFirestoreService>();
        firestore
            .Setup(f => f.GetHeadToHeadAsync(
                "test-bank",
                It.IsAny<IReadOnlyList<string>>(),
                "all",
                It.IsAny<int>(), It.IsAny<int>(), default))
            .ReturnsAsync(expected);

        var ctrl = new BenchmarkController(firestore.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        var ok = Assert.IsType<OkObjectResult>(
            await ctrl.GetHeadToHead(competitors: ["rival-bank"], businessFamily: "all"));

        Assert.Equal(expected, ok.Value);
    }

    // ── BenchmarkController — Retention Risk RBAC ─────────────────────────────

    [Fact]
    public async Task RetentionRisk_FreeTierUser_Returns403()
    {
        var ctrl = new BenchmarkController(new Mock<IFirestoreService>().Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = MakeContext(tier: SubscriptionTier.Free)
            }
        };

        Assert.Equal(403, (await ctrl.GetRetentionRisk() as ObjectResult)?.StatusCode);
    }

    [Fact]
    public async Task RetentionRisk_EnterpriseTier_ReturnsOk()
    {
        var expected = new RetentionRiskResponse("test-bank", 3, []);
        var firestore = new Mock<IFirestoreService>();
        firestore
            .Setup(f => f.GetRetentionRiskAsync("test-bank", 3, default))
            .ReturnsAsync(expected);

        var ctrl = new BenchmarkController(firestore.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        var ok = Assert.IsType<OkObjectResult>(await ctrl.GetRetentionRisk(months: 3));
        Assert.Equal(expected, ok.Value);
    }

    [Fact]
    public async Task RetentionRisk_MonthsClamped_Between2And12()
    {
        int capturedMonths = -1;

        var firestore = new Mock<IFirestoreService>();
        firestore
            .Setup(f => f.GetRetentionRiskAsync("test-bank", It.IsAny<int>(), default))
            .Callback<string, int, CancellationToken>((_, m, _) => capturedMonths = m)
            .ReturnsAsync(new RetentionRiskResponse("test-bank", 2, []));

        var ctrl = new BenchmarkController(firestore.Object)
        {
            ControllerContext = new ControllerContext { HttpContext = MakeContext() }
        };

        // Request 99 months — should be clamped to 12
        await ctrl.GetRetentionRisk(months: 99);
        Assert.Equal(12, capturedMonths);

        // Request 0 months — should be clamped to 2
        await ctrl.GetRetentionRisk(months: 0);
        Assert.Equal(2, capturedMonths);
    }
}
