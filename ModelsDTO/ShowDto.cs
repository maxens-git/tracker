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
    public DateTime UpdatedAt { get; set; }
    public DateTime? ListAddedAt { get; set; }

    public int NumberOfSeasons { get; set; }
    public int NumberOfEpisodes { get; set; }
    public DateTime? LastAirDate { get; set; }
    public List<Season> Seasons { get; set; } = new();

    public List<int> ListIds { get; set; } = new();

    public ShowDto() {}

    public ShowDto(Show show, DateTime? listAddedAt = null)
    {
        Id = show.Id;
        TmdbId = show.TmdbId;
        Title = show.Title;
        OriginalTitle = show.OriginalTitle;
        Overview = show.Overview;
        Status = show.Status;
        Tagline = show.Tagline;
        PosterPath = show.PosterPath;
        BackdropPath = show.BackdropPath;
        VoteAverage = show.VoteAverage;
        VoteCount = show.VoteCount;
        Popularity = show.Popularity;
        Liked = show.Liked;
        Seen = show.Seen;
        ReleaseDate = show.ReleaseDate;
        Genres = show.Genres;
        AddedAt = show.AddedAt;
        UpdatedAt = show.UpdatedAt;
        Ratings = new MediaRatingsDto(show.ToRatings());
        NumberOfSeasons = show.NumberOfSeasons;
        NumberOfEpisodes = show.NumberOfEpisodes;
        LastAirDate = show.LastAirDate;
        Seasons = show.Seasons;
        ListIds = show.MediaLists?.Select(l => l.Id).ToList() ?? new List<int>();
        ListAddedAt = listAddedAt;
    }
}
