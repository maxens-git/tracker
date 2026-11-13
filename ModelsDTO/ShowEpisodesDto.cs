using System.ComponentModel.DataAnnotations;
using Tracker.Models;

namespace Tracker.ModelsDTO;

public class EpisodeSeenDto
{
    public int SeasonNumber { get; set; }
    public int EpisodeNumber { get; set; }
    public bool Seen { get; set; }
    public int WatchCount { get; set; }

    public EpisodeSeenDto(UserEpisode e)
    {
        SeasonNumber = e.SeasonNumber;
        EpisodeNumber = e.EpisodeNumber;
        Seen = e.Seen;
        WatchCount = e.WatchCount;
    }
}

public class AddEpisodeWatchDto
{
    [Range(typeof(DateTime), "1000-01-01", "9999-12-31T23:59:59.9999999", ParseLimitsInInvariantCulture = true)]
    public DateTime WatchedAt { get; set; } = DateTime.UtcNow;
}

public class MarkSeasonSeenDto
{
    public bool Seen { get; set; }
    public List<int> EpisodeNumbers { get; set; } = new();
}

public class MarkShowSeenDto
{
    public bool Seen { get; set; }
    [MaxLength(500)]
    public string? PosterPath { get; set; }
    [MaxLength(500)]
    public string? Title { get; set; }
    public List<MediaGenreDto> Genres { get; set; } = new();
    public List<SeasonEpisodesDto> Seasons { get; set; } = new();
}

public class SeasonEpisodesDto
{
    [Range(0, int.MaxValue)]
    public int SeasonNumber { get; set; }
    public List<int> EpisodeNumbers { get; set; } = new();
}

/// <summary>Série dont au moins un épisode est vu mais qui n'est pas terminée (« En cours »).</summary>
public class InProgressShowDto
{
    public int ShowTmdbId { get; set; }
    public string? PosterPath { get; set; }
    public int SeenEpisodeCount { get; set; }
    public int LastSeasonNumber { get; set; }
    public int LastEpisodeNumber { get; set; }
    public DateTime LastWatchedAt { get; set; }
}
