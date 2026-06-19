namespace Tracker.ModelsDTO;

public record SettingsDto(
    bool NtfyEnabled,
    string? NtfyUrl,
    string? NtfyTopic,
    string? NtfyToken,
    int NotifyDaysAhead,
    int NotificationHour,
    int NotificationMinute,
    DateTime UpdatedAt);

public record UpdateSettingsDto(
    bool NtfyEnabled,
    string? NtfyUrl,
    string? NtfyTopic,
    string? NtfyToken,
    int NotifyDaysAhead,
    int NotificationHour,
    int NotificationMinute);
