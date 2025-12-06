using System;
using System.Collections.Generic;

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
}
