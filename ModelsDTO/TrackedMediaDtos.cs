namespace Tracker.ModelsDTO;

public record TrackedMediaDto(
    int Id,
    int TmdbId,
    string MediaType,
    string Title,
    string? PosterPath,
    DateTime AddedAt);

public record AddTrackedMediaDto(
    int TmdbId,
    string MediaType,
    string Title,
    string? PosterPath);

public record TrackedMediaStateDto(int TmdbId, string MediaType, bool Tracked);
