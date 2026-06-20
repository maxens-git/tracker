using Tracker.Models;

namespace Tracker.Services;

public record ReleaseCandidate(
    int TmdbId,
    MediaType MediaType,
    string MediaTitle,
    string ReleaseKey,
    string ReleaseTitle,
    DateOnly ReleaseDate,
    string? PosterPath);

/// <summary>
/// Instantané brut d'une saison TMDB, datée ou non. <see cref="AirDate"/> est la
/// chaîne <c>yyyy-MM-dd</c> renvoyée par TMDB, ou <c>null</c> si la date n'est pas
/// encore publiée (saison annoncée mais non programmée).
/// </summary>
public record SeasonInfo(
    int SeasonNumber,
    string Name,
    string? AirDate,
    int EpisodeCount);
