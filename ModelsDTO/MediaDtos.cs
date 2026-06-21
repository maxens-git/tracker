namespace Tracker.ModelsDTO;

public class AddToWatchlistDto
{
    public string? PosterPath { get; set; }
    public int? Runtime { get; set; }
    public List<MediaGenreDto> Genres { get; set; } = new();
}

public class MarkSeenDto
{
    public bool Seen { get; set; }
    public string? PosterPath { get; set; }
    public int? Runtime { get; set; }
    public List<MediaGenreDto> Genres { get; set; } = new();
}

public class MediaGenreDto
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
}

public class AddListItemDto
{
    public int TmdbId { get; set; }
    public string MediaType { get; set; } = "movie";
    public string? PosterPath { get; set; }
}
