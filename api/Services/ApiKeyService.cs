namespace PomApi.Services;

/// <summary>
/// Validates API keys against Firestore and resolves the associated company context.
/// Delegates caching to <see cref="FirestoreService"/>.
/// </summary>
public sealed class ApiKeyService
{
    private readonly FirestoreService _firestore;
    private readonly ILogger<ApiKeyService> _logger;

    public ApiKeyService(FirestoreService firestore, ILogger<ApiKeyService> logger)
    {
        _firestore = firestore;
        _logger = logger;
    }

    /// <summary>
    /// Validates the given API key and returns the associated <see cref="Models.ApiKeyRecord"/>,
    /// or <c>null</c> if the key is invalid or inactive.
    /// </summary>
    public async Task<Models.ApiKeyRecord?> ValidateAsync(string key)
    {
        if (string.IsNullOrWhiteSpace(key))
            return null;

        var record = await _firestore.GetApiKeyAsync(key);
        if (record is null)
        {
            _logger.LogWarning("Invalid or inactive API key presented");
            return null;
        }

        return record;
    }
}
