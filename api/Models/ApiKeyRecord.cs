namespace PomApi.Models;

/// <summary>
/// Represents a document from the <c>daas_api_keys</c> Firestore collection.
/// </summary>
public record ApiKeyRecord(
    string KeyId,
    string UserId,
    string CompanyId,
    string CompanyName,
    string IndustryName,
    string Key,
    bool Active,
    int RateLimitHour,
    int EmployeeCount
);

/// <summary>
/// Attached to every authenticated HTTP context so downstream controllers
/// can read company metadata without re-querying Firestore.
/// </summary>
public record CompanyContext(
    string CompanyId,
    string CompanyName,
    string IndustryName,
    int EmployeeCount
);
