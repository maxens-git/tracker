using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("Episodes")]
public class Episode
{
    [Key]
    public int Id { get; set; }
    
    public int TmdbId { get; set; }

    [MaxLength(255)]
    public string Name { get; set; } = string.Empty;
    
    public string? Overview { get; set; }
    
    public int EpisodeNumber { get; set; }
    public int Runtime { get; set; }
    public double VoteAverage { get; set; }
    public DateTime? AirDate { get; set; }

    [MaxLength(255)]
    public string? StillPath { get; set; }

    public bool Seen { get; set; } = false;

    public int SeasonId { get; set; }
    [ForeignKey("SeasonId")]
    public Season Season { get; set; } = null!;
}