using Tracker.Models;

namespace Tracker.ModelsDTO;

public class EpisodeDto
{
    public int Id { get; set; }
    public int TmdbId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Overview { get; set; }
    public int EpisodeNumber { get; set; }
    public int Runtime { get; set; }
    public double VoteAverage { get; set; }
    public DateTime? AirDate { get; set; }
    public string? StillPath { get; set; }
    public bool Seen { get; set; }
    public int SeasonId { get; set; }
    public List<int> ListIds { get; set; } = new();

    public EpisodeDto() {}

    public EpisodeDto(Episode episode)
    {
        Id = episode.Id;
        TmdbId = episode.TmdbId;
        Name = episode.Name;
        Overview = episode.Overview;
        EpisodeNumber = episode.EpisodeNumber;
        Runtime = episode.Runtime;
        VoteAverage = episode.VoteAverage;
        AirDate = episode.AirDate;
        StillPath = episode.StillPath;
        Seen = episode.Seen;
        SeasonId = episode.SeasonId;
    }
}
