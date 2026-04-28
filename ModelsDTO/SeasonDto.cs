using Tracker.Models;

namespace Tracker.ModelsDTO;

public class SeasonDto
{
    public int Id { get; set; }
    public int TmdbId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Overview { get; set; }
    public int SeasonNumber { get; set; }
    public int EpisodeCount { get; set; }
    public DateTime? AirDate { get; set; }
    public string? PosterPath { get; set; }
    public bool Seen { get; set; }
    public int ShowId { get; set; }
    public List<EpisodeDto> Episodes { get; set; } = new();
    public List<int> ListIds { get; set; } = new();

    public SeasonDto() {}

    public SeasonDto(Season season)
    {
        Id = season.Id;
        TmdbId = season.TmdbId;
        Name = season.Name;
        Overview = season.Overview;
        SeasonNumber = season.SeasonNumber;
        EpisodeCount = season.EpisodeCount;
        AirDate = season.AirDate;
        PosterPath = season.PosterPath;
        Seen = season.Seen;
        ShowId = season.ShowId;
        Episodes = season.Episodes?.Select(e => new EpisodeDto(e)).ToList() ?? new List<EpisodeDto>();
    }
}
