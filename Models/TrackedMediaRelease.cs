using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("TrackedMediaReleases")]
public class TrackedMediaRelease
{
    public TrackedMediaRelease(int tmdbId, MediaType mediaType, string title, string? posterPath)
    {
        TmdbId = tmdbId;
        MediaType = mediaType;
        Title = title;
        PosterPath = posterPath;
    }

    [Key]
    public int Id { get; set; }

    public int TmdbId { get; set; }

    public MediaType MediaType { get; set; }

    [MaxLength(300)]
    public string Title { get; set; }

    [MaxLength(500)]
    public string? PosterPath { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
}
