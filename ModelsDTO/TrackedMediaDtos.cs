using System.ComponentModel.DataAnnotations;
namespace Tracker.ModelsDTO;

public record TrackedMediaDto(
    int Id,
    int TmdbId,
    string MediaType,
    string Title,
    string? PosterPath,
    DateTime AddedAt);

public record AddTrackedMediaDto(
    [Range(1, int.MaxValue)] int TmdbId,
    [RegularExpression("(?i)^(movie|show|tv)$")] string MediaType,
    [StringLength(300)] string Title,
    [StringLength(500)] string? PosterPath);

public record TrackedMediaStateDto(int TmdbId, string MediaType, bool Tracked);
