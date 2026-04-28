using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("MediaListMovie")]
public class MediaListMovie : BaseEntity
{
    public int MediaListId { get; set; }
    public MediaList MediaList { get; set; } = null!;

    public int MovieId { get; set; }
    public Movie Movie { get; set; } = null!;
}
