namespace Tracker.ModelsDTO;

public record SettingsDto(
    bool NtfyEnabled,
    string? NtfyUrl,
    string? NtfyTopic,
    string? NtfyToken,
    int NotifyDaysAhead,
    int NotificationHour,
    int NotificationMinute,
    bool TorrentsEnabled,
    string? ProwlarrUrl,
    string? ProwlarrApiKey,
    string? AllDebridApiKey,
    string? TmdbApiKey,
    string? TmdbBaseUrl,
    string? TmdbLanguage,
    DateTime UpdatedAt);

public record UpdateSettingsDto(
    bool NtfyEnabled,
    string? NtfyUrl,
    string? NtfyTopic,
    string? NtfyToken,
    int NotifyDaysAhead,
    int NotificationHour,
    int NotificationMinute,
    // Nullable : les clients qui n'envoient pas ce champ (ex. iOS) conservent
    // la valeur existante au lieu de désactiver les torrents par défaut.
    bool? TorrentsEnabled,
    string? ProwlarrUrl,
    string? ProwlarrApiKey,
    string? AllDebridApiKey,
    string? TmdbApiKey,
    string? TmdbBaseUrl,
    string? TmdbLanguage);
