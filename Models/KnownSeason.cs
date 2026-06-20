using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

/// <summary>
/// Instantané d'une saison connue d'une série suivie. Sert de mémoire entre deux
/// passages du worker : une saison absente de cette table puis remontée par TMDB
/// est une « nouvelle saison annoncée ». <see cref="AirDate"/> est la chaîne brute
/// TMDB (<c>yyyy-MM-dd</c>) ou <c>null</c> tant que la date n'est pas publiée.
/// </summary>
[Table("KnownSeasons")]
public class KnownSeason
{
    public KnownSeason(int tmdbId, int seasonNumber, string seasonName, string? airDate, int episodeCount)
    {
        TmdbId = tmdbId;
        SeasonNumber = seasonNumber;
        SeasonName = seasonName;
        AirDate = airDate;
        EpisodeCount = episodeCount;
    }

    [Key]
    public int Id { get; set; }

    public int TmdbId { get; set; }

    public int SeasonNumber { get; set; }

    [MaxLength(300)]
    public string SeasonName { get; set; }

    [MaxLength(10)]
    public string? AirDate { get; set; }

    public int EpisodeCount { get; set; }

    public DateTime FirstSeenAt { get; set; } = DateTime.UtcNow;

    public DateTime LastCheckedAt { get; set; } = DateTime.UtcNow;
}
