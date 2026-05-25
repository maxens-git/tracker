using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("MediaListItems")]
public class MediaListItem
{
    public MediaListItem(int mediaListId, int tmdbId, MediaType mediaType, string? posterPath = null)
    {
        MediaListId = mediaListId;
        TmdbId = tmdbId;
        MediaType = mediaType;
        PosterPath = posterPath;
    }

    [Key]
    public int Id { get; set; }

    public int MediaListId { get; set; }
    public MediaList MediaList { get; set; } = null!;

    public int TmdbId { get; set; }

    public MediaType MediaType { get; set; }

    [MaxLength(500)]
    public string? PosterPath { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
}
