using Tracker.Models;

namespace Tracker.ModelsDTO;

public class MovieDto
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
    public DateTime UpdatedAt { get; set; }
    public DateTime? ListAddedAt { get; set; }

    public int Runtime { get; set; }
    public long Budget { get; set; }
    public long Revenue { get; set; }
    public string? ImdbId { get; set; }

    public List<int> ListIds { get; set; } = new();

    public MovieDto() {}

    public MovieDto(Movie movie, DateTime? listAddedAt = null)
    {
        Id = movie.Id;
        TmdbId = movie.TmdbId;
        Title = movie.Title;
        OriginalTitle = movie.OriginalTitle;
        Overview = movie.Overview;
        Status = movie.Status;
        Tagline = movie.Tagline;
        PosterPath = movie.PosterPath;
        BackdropPath = movie.BackdropPath;
        VoteAverage = movie.VoteAverage;
        VoteCount = movie.VoteCount;
        Popularity = movie.Popularity;
        Liked = movie.Liked;
        Seen = movie.Seen;
        ReleaseDate = movie.ReleaseDate;
        Genres = movie.Genres;
        AddedAt = movie.AddedAt;
        UpdatedAt = movie.UpdatedAt;
        Ratings = new MediaRatingsDto(movie.ToRatings());
        Runtime = movie.Runtime;
        Budget = movie.Budget;
        Revenue = movie.Revenue;
        ImdbId = movie.ImdbId;
        ListIds = movie.MediaLists?.Select(l => l.Id).ToList() ?? new List<int>();
        ListAddedAt = listAddedAt;
    }
}
