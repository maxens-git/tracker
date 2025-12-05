using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("Movies")]
public class Movie : BaseMedia
{
    public int Runtime { get; set; }
    public long Budget { get; set; }
    public long Revenue { get; set; }
    
    [MaxLength(50)]
    public string? ImdbId { get; set; }
}