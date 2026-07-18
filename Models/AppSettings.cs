using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("Settings")]
public class AppSettings
{
    [Key]
    public int Id { get; set; } = 1;

    public bool NtfyEnabled { get; set; } = false;

    [MaxLength(500)]
    public string? NtfyUrl { get; set; }

    [MaxLength(200)]
    public string? NtfyTopic { get; set; }

    [MaxLength(500)]
    public string? NtfyToken { get; set; }

    public int NotifyDaysAhead { get; set; } = 1;

    public int NotificationHour { get; set; } = 9;

    public int NotificationMinute { get; set; } = 0;

    // Recherche de torrents (Prowlarr) + débridage (AllDebrid).
    public bool TorrentsEnabled { get; set; } = true;

    [MaxLength(500)]
    public string? ProwlarrUrl { get; set; }

    [MaxLength(200)]
    public string? ProwlarrApiKey { get; set; }

    [MaxLength(200)]
    public string? AllDebridApiKey { get; set; }

    // Configuration TMDB (appelée directement par les clients, et par le backend
    // pour les sorties). Vide ⇒ repli sur les valeurs d'appsettings.json.
    [MaxLength(200)]
    public string? TmdbApiKey { get; set; }

    [MaxLength(500)]
    public string? TmdbBaseUrl { get; set; }

    [MaxLength(20)]
    public string? TmdbLanguage { get; set; }

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
