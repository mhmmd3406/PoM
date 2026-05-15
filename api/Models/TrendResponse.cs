namespace PomApi.Models;

public record TrendPoint(
    DateTimeOffset WeekStart,
    double Score,
    Dimensions Dimensions,
    int ParticipantCount
);

public record TrendResponse(
    string CompanyId,
    int Days,
    IReadOnlyList<TrendPoint> Points
);
