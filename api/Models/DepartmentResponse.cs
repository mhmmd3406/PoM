namespace PomApi.Models;

public record DepartmentData(
    string DepartmentId,
    string DepartmentName,
    double Score,
    Dimensions Dimensions,
    int EmployeeCount,
    int CheckinCount,
    bool MeetsThreshold
);

public record DepartmentsResponse(
    IReadOnlyList<DepartmentData> Departments,
    int Threshold
);
