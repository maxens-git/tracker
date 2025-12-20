using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("Trailers")]
public class Trailer
{
    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(100)]
    public string TmdbKey { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(100)]
    public string? Key { get; set; }

    [MaxLength(50)]
    public string? Site { get; set; }

    [MaxLength(50)]
    public string? Type { get; set; }

    public bool Official { get; set; }

    [MaxLength(10)]
    public string? Language { get; set; }

    public DateTime? PublishedAt { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;

    public int? MovieId { get; set; }
    public Movie? Movie { get; set; }

    public int? ShowId { get; set; }
    public Show? Show { get; set; }
}
