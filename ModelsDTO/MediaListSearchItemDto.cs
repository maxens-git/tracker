namespace Tracker.ModelsDTO;

public class MediaListSearchItemDto
{
    public int Id { get; set; }
    public int TmdbId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? PosterPath { get; set; }
    public DateTime? ReleaseDate { get; set; }
    public double? VoteAverage { get; set; }
    public double? Popularity { get; set; }
    public DateTime? LastUpdated { get; set; }
    public string MediaType { get; set; } = string.Empty;
}
