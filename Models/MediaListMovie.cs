using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("MediaListMovie")]
public class MediaListMovie
{
    public int MediaListId { get; set; }
    public MediaList MediaList { get; set; } = null!;

    public int MovieId { get; set; }
    public Movie Movie { get; set; } = null!;

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
}
