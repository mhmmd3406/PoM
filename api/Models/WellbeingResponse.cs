namespace PomApi.Models;

public record Dimensions(
    double Mood,
    double Stress,
    double Team,
    double Growth,
    double Balance
);

public enum RetentionRisk
{
    Low,
    Medium,
    High
}

public record WellbeingResponse(
    string CompanyId,
    string CompanyName,
    double Score,
    Dimensions Dimensions,
    double ParticipationRate,
    RetentionRisk RetentionRisk,
    int EmployeeCount,
    int CheckinCount,
    DateTimeOffset GeneratedAt
);
