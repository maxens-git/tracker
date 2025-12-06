using System;
using System.Collections.Generic;

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
}
