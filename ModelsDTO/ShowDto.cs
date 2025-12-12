using Tracker.Models;

namespace Tracker.ModelsDTO;

public class ShowDto
{
    public int Id { get; set; }
    public int TmdbId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? OriginalTitle { get; set; }
    public string? Overview { get; set; }
    public string? Status { get; set; }
    public string? Tagline { get; set; }
    public string? PosterPath { get; set; }
    public string? BackdropPath { get; set; }
    public double VoteAverage { get; set; }
    public int VoteCount { get; set; }
    public double Popularity { get; set; }
    public MediaRatingsDto Ratings { get; set; } = new();
    public bool Liked { get; set; }
    public bool Seen { get; set; }
    public DateTime? ReleaseDate { get; set; }
    public string? Genres { get; set; }
    public DateTime AddedAt { get; set; }
    public DateTime LastUpdated { get; set; }
    public DateTime? ListAddedAt { get; set; }
    
    public int NumberOfSeasons { get; set; }
    public int NumberOfEpisodes { get; set; }
    public DateTime? LastAirDate { get; set; }
    public List<Season> Seasons { get; set; } = new();
    
    public List<int> ListIds { get; set; } = new();
}
