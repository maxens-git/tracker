using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

public abstract class BaseMedia
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int TmdbId { get; set; }

    [MaxLength(255)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? OriginalTitle { get; set; }

    public string? Overview { get; set; }

    [MaxLength(50)]
    public string? Status { get; set; }

    [MaxLength(255)]
    public string? Tagline { get; set; }

    [MaxLength(255)]
    public string? PosterPath { get; set; }
    [MaxLength(255)]
    public string? BackdropPath { get; set; }

    public double VoteAverage { get; set; }
    public int VoteCount { get; set; }
    public double Popularity { get; set; }

    public bool Liked { get; set; } = false;
    public bool Seen { get; set; } = false;

    public DateTime? ReleaseDate { get; set; }

    public string? Genres { get; set; } 

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastUpdated { get; set; } = DateTime.UtcNow;
}