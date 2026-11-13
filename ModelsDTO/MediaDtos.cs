using System.ComponentModel.DataAnnotations;

namespace Tracker.ModelsDTO;

public class AddToWatchlistDto
{
    [MaxLength(500)]
    public string? PosterPath { get; set; }
    [Range(0, int.MaxValue)]
    public int? Runtime { get; set; }
    [MaxLength(500)]
    public string? Title { get; set; }
    public List<MediaGenreDto> Genres { get; set; } = new();
}

public class MarkSeenDto
{
    public bool Seen { get; set; }
    [MaxLength(500)]
    public string? PosterPath { get; set; }
    [Range(0, int.MaxValue)]
    public int? Runtime { get; set; }
    [MaxLength(500)]
    public string? Title { get; set; }
    public List<MediaGenreDto> Genres { get; set; } = new();
}

public class AddWatchDto
{
    [Range(typeof(DateTime), "1000-01-01", "9999-12-31T23:59:59.9999999", ParseLimitsInInvariantCulture = true)]
    public DateTime WatchedAt { get; set; } = DateTime.UtcNow;
    [MaxLength(500)]
    public string? PosterPath { get; set; }
    [Range(0, int.MaxValue)]
    public int? Runtime { get; set; }
    [MaxLength(500)]
    public string? Title { get; set; }
    public List<MediaGenreDto> Genres { get; set; } = new();
}

public class MediaGenreDto
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
}

public class AddListItemDto
{
    [Range(1, int.MaxValue)]
    public int TmdbId { get; set; }
    [RegularExpression("(?i)^(movie|show|tv)$")]
    public string MediaType { get; set; } = "movie";
    [MaxLength(500)]
    public string? PosterPath { get; set; }
    [MaxLength(500)]
    public string? Title { get; set; }
    public List<MediaGenreDto>? Genres { get; set; }
}
