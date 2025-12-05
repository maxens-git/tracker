using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("Seasons")]
public class Season
{
    [Key]
    public int Id { get; set; }

    public int TmdbId { get; set; }
    
    [MaxLength(255)]
    public string Name { get; set; } = string.Empty;
    
    public string? Overview { get; set; }
    
    public int SeasonNumber { get; set; }
    public int EpisodeCount { get; set; }
    public DateTime? AirDate { get; set; }
    
    [MaxLength(255)]
    public string? PosterPath { get; set; }

    public int ShowId { get; set; }
    [ForeignKey("ShowId")]
    public Show Show { get; set; } = null!;

    public List<Episode> Episodes { get; set; } = new();
}