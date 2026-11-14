using System.ComponentModel.DataAnnotations;

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
    DateTime UpdatedAt,
    bool? IosLocalNotificationsEnabled = null);

public record UpdateSettingsDto(
    bool NtfyEnabled,
    [StringLength(500)] string? NtfyUrl,
    [StringLength(200)] string? NtfyTopic,
    [StringLength(500)] string? NtfyToken,
    int NotifyDaysAhead,
    int NotificationHour,
    int NotificationMinute,
    // Nullable : les clients qui n'envoient pas ce champ (ex. iOS) conservent
    // la valeur existante au lieu de désactiver les torrents par défaut.
    bool? TorrentsEnabled,
    [StringLength(500)] string? ProwlarrUrl,
    [StringLength(200)] string? ProwlarrApiKey,
    [StringLength(200)] string? AllDebridApiKey,
    [StringLength(200)] string? TmdbApiKey,
    [StringLength(500)] string? TmdbBaseUrl,
    [StringLength(20)] string? TmdbLanguage,
    bool? IosLocalNotificationsEnabled = null);
