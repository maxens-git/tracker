namespace Tracker.ModelsDTO;

public class TrailerDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Key { get; set; } = string.Empty;
    public string Site { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public bool Official { get; set; }
    public string? Language { get; set; }
    public string? PublishedAt { get; set; }
}

public class TrailersResponseDto
{
    public int TmdbId { get; set; }
    public List<TrailerDto> Trailers { get; set; } = new();
}
