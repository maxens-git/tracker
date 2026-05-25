namespace Tracker.ModelsDTO;

public class AddToWatchlistDto
{
    public string? PosterPath { get; set; }
    public int? Runtime { get; set; }
}

public class MarkSeenDto
{
    public bool Seen { get; set; }
    public int? Runtime { get; set; }
}

public class AddListItemDto
{
    public int TmdbId { get; set; }
    public string MediaType { get; set; } = "movie";
    public string? PosterPath { get; set; }
}
