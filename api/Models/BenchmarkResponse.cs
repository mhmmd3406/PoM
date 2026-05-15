namespace PomApi.Models;

public record BenchmarkDimension(
    string Dimension,
    double CompanyScore,
    double IndustryAverage,
    double Percentile
);

public record BenchmarkResponse(
    string CompanyId,
    string IndustryName,
    double OverallPercentile,
    IReadOnlyList<BenchmarkDimension> Dimensions,
    double TopQuartileThreshold
);
