using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Tracker.ModelsDTO;

namespace Tracker.Models;

[Table("Shows")]
public class Show : BaseMedia
{
    public int NumberOfSeasons { get; set; }
    public int NumberOfEpisodes { get; set; }
    
    public DateTime? LastAirDate { get; set; }

    public List<Season> Seasons { get; set; } = new();
    public List<MediaList> MediaLists { get; set; } = new();
    public List<MediaListShow> MediaListShows { get; set; } = new();
    public List<ShowCast> ShowCasts { get; set; } = new();
    public List<ShowCrew> ShowCrews { get; set; } = new();
    public List<Trailer> Trailers { get; set; } = new();

    public Show() {}

    public Show(ModelsDTO.ShowDto dto)
    {
        Id = dto.Id;
        TmdbId = dto.TmdbId;
        Title = dto.Title;
        OriginalTitle = dto.OriginalTitle;
        Overview = dto.Overview;
        Status = dto.Status;
        Tagline = dto.Tagline;
        PosterPath = dto.PosterPath;
        BackdropPath = dto.BackdropPath;
        VoteAverage = dto.VoteAverage;
        VoteCount = dto.VoteCount;
        Popularity = dto.Popularity;
        Liked = dto.Liked;
        Seen = dto.Seen;
        ReleaseDate = dto.ReleaseDate;
        Genres = dto.Genres;
        AddedAt = dto.AddedAt;
        UpdatedAt = dto.UpdatedAt;
        ImdbRating = dto.Ratings?.ImdbRating;
        ImdbVotes = dto.Ratings?.ImdbVotes;
        RottenTomatoesRating = dto.Ratings?.RottenTomatoesRating;
        NumberOfSeasons = dto.NumberOfSeasons;
        NumberOfEpisodes = dto.NumberOfEpisodes;
        LastAirDate = dto.LastAirDate;
    }

}