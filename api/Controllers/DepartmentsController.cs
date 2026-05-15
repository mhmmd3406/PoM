using Microsoft.AspNetCore.Mvc;
using PomApi.Middleware;
using PomApi.Models;
using PomApi.Services;

namespace PomApi.Controllers;

[ApiController]
[Route("api/v1")]
[Produces("application/json")]
public sealed class DepartmentsController : ControllerBase
{
    private readonly FirestoreService _firestore;
    private readonly ThresholdService _thresholds;

    public DepartmentsController(FirestoreService firestore, ThresholdService thresholds)
    {
        _firestore = firestore;
        _thresholds = thresholds;
    }

    /// <summary>
    /// Returns department-level wellbeing data.
    /// Departments with fewer than the department threshold (default 10) unique participants
    /// are returned with <c>meetsThreshold: false</c> and zeroed-out scores.
    /// </summary>
    /// <response code="200">Department list returned successfully.</response>
    [HttpGet("departments")]
    [ProducesResponseType(typeof(DepartmentsResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetDepartments()
    {
        var ctx = ApiKeyMiddleware.GetCompanyContext(HttpContext);
        var deptMinN = await _thresholds.GetDepartmentMinNAsync();

        var checkins = await _firestore.GetCompanyCheckinsAsync(ctx.CompanyId);

        var departments = InsightsAggregator.AggregateDepartments(checkins, deptMinN);

        return Ok(new DepartmentsResponse(
            Departments: departments,
            Threshold:   deptMinN
        ));
    }
}
