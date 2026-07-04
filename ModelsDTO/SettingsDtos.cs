namespace Tracker.ModelsDTO;

public record SettingsDto(
    bool NtfyEnabled,
    string? NtfyUrl,
    string? NtfyTopic,
    string? NtfyToken,
    int NotifyDaysAhead,
    int NotificationHour,
    int NotificationMinute,
    string? ProwlarrUrl,
    string? ProwlarrApiKey,
    string? AllDebridApiKey,
    DateTime UpdatedAt);

public record UpdateSettingsDto(
    bool NtfyEnabled,
    string? NtfyUrl,
    string? NtfyTopic,
    string? NtfyToken,
    int NotifyDaysAhead,
    int NotificationHour,
    int NotificationMinute,
    string? ProwlarrUrl,
    string? ProwlarrApiKey,
    string? AllDebridApiKey);
