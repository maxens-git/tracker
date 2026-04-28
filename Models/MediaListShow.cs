using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("MediaListShow")]
public class MediaListShow : BaseEntity
{
    public int MediaListId { get; set; }
    public MediaList MediaList { get; set; } = null!;

    public int ShowId { get; set; }
    public Show Show { get; set; } = null!;
}
