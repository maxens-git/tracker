using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Tracker.ModelsDTO;

namespace Tracker.Models;

[Table("Movies")]
public class Movie : BaseMedia
{
    public int Runtime { get; set; }
    public long Budget { get; set; }
    public long Revenue { get; set; }
    
    [MaxLength(50)]
    public string? ImdbId { get; set; }

    public List<MediaList> MediaLists { get; set; } = new();
    public List<MediaListMovie> MediaListMovies { get; set; } = new();
    public List<MovieCast> MovieCasts { get; set; } = new();
    public List<MovieCrew> MovieCrews { get; set; } = new();
    public List<Trailer> Trailers { get; set; } = new();

    public Movie() {}

    public Movie(ModelsDTO.MovieDto dto)
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
        LastUpdated = dto.LastUpdated;
        ImdbRating = dto.Ratings?.ImdbRating;
        ImdbVotes = dto.Ratings?.ImdbVotes;
        RottenTomatoesRating = dto.Ratings?.RottenTomatoesRating;
        Runtime = dto.Runtime;
        Budget = dto.Budget;
        Revenue = dto.Revenue;
        ImdbId = dto.ImdbId;
    }

    public ModelsDTO.MovieDto ToDto()
    {
        return new ModelsDTO.MovieDto
        {
            Id = Id,
            TmdbId = TmdbId,
            Title = Title,
            OriginalTitle = OriginalTitle,
            Overview = Overview,
            Status = Status,
            Tagline = Tagline,
            PosterPath = PosterPath,
            BackdropPath = BackdropPath,
            VoteAverage = VoteAverage,
            VoteCount = VoteCount,
            Popularity = Popularity,
            Liked = Liked,
            Seen = Seen,
            ReleaseDate = ReleaseDate,
            Genres = Genres,
            AddedAt = AddedAt,
            LastUpdated = LastUpdated,
            Ratings = ToRatings().ToDto(),
            Runtime = Runtime,
            Budget = Budget,
            Revenue = Revenue,
            ImdbId = ImdbId,
            ListIds = MediaLists?.ConvertAll(l => l.Id) ?? new List<int>()
        };
    }

    public ModelsDTO.MovieDto ToDto(DateTime? listAddedAt)
    {
        ModelsDTO.MovieDto dto = ToDto();
        dto.ListAddedAt = listAddedAt;
        return dto;
    }
}