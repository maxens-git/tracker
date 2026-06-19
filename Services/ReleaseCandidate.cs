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
