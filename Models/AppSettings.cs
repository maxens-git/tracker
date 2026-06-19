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

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
