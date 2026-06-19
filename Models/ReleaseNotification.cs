using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("ReleaseNotifications")]
public class ReleaseNotification
{
    public ReleaseNotification(int tmdbId, MediaType mediaType, string releaseKey)
    {
        TmdbId = tmdbId;
        MediaType = mediaType;
        ReleaseKey = releaseKey;
    }

    [Key]
    public int Id { get; set; }

    public int TmdbId { get; set; }

    public MediaType MediaType { get; set; }

    [MaxLength(120)]
    public string ReleaseKey { get; set; }

    public DateTime SentAt { get; set; } = DateTime.UtcNow;
}
