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

    public bool Seen { get; set; } = false;

    public int ShowId { get; set; }
    [ForeignKey("ShowId")]
    public Show Show { get; set; } = null!;

    public List<Episode> Episodes { get; set; } = new();
    public ModelsDTO.SeasonDto ToDto()
    {
        return new ModelsDTO.SeasonDto
        {
            Id = Id,
            TmdbId = TmdbId,
            Name = Name,
            Overview = Overview,
            SeasonNumber = SeasonNumber,
            EpisodeCount = EpisodeCount,
            AirDate = AirDate,
            PosterPath = PosterPath,
            Seen = Seen,
            ShowId = ShowId,
            Episodes = Episodes?.ConvertAll(e => e.ToDto()) ?? new List<ModelsDTO.EpisodeDto>(),
            ListIds = new List<int>() // Optionally populate if you add list support for seasons
        };
    }
}