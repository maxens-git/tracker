using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.Models.TMDbResponses;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MoviesController : ControllerBase
{
    private readonly ApiDbContext _context;
    private readonly TMDbService _tmdbService;
    private readonly OmdbService _omdbService;

    public MoviesController(ApiDbContext context, TMDbService tmdbService, OmdbService omdbService)
    {
        _context = context;
        _tmdbService = tmdbService;
        _omdbService = omdbService;
    }

    [HttpGet("{tmdbId}")]
    public async Task<ActionResult<MovieDto>> GetByTmdbId(int tmdbId)
    {
        Movie? movie = await _context.Movies
            .Include(m => m.MediaLists)
            .FirstOrDefaultAsync(m => m.TmdbId == tmdbId);

        if (movie == null)
        {
            TMDbMovieResponse? tmdbMovie = await _tmdbService.GetMovieAsync(tmdbId);
            if (tmdbMovie == null)
                return NotFound("Movie not found on TMDb");

            movie = BuildMovieFromTmdb(tmdbMovie);

            _context.Movies.Add(movie);
            await _context.SaveChangesAsync();
        }

        return MapToDto(movie);
    }

    [HttpPost("{tmdbId}/watchlist")]
    public async Task<IActionResult> AddToWatchlist(int tmdbId)
    {
        Movie? movie = await _context.Movies.Include(m => m.MediaLists).FirstOrDefaultAsync(m => m.TmdbId == tmdbId);
        if (movie == null)
        {
            TMDbMovieResponse? tmdbMovie = await _tmdbService.GetMovieAsync(tmdbId);
            if (tmdbMovie == null)
                return NotFound("Movie not found on TMDb");

            movie = BuildMovieFromTmdb(tmdbMovie);
            _context.Movies.Add(movie);
            await _context.SaveChangesAsync();
        }

        MediaList? watchlist = await _context.MediaLists.Include(l => l.Movies)
            .FirstOrDefaultAsync(l => l.IsSystem && l.Name == "Watchlist");
        if (watchlist == null)
        {
            watchlist = new MediaList
            {
                Name = "Watchlist",
                IsSystem = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.MediaLists.Add(watchlist);
            await _context.SaveChangesAsync();
        }

        if (watchlist.Movies.Any(m => m.TmdbId == tmdbId))
            return BadRequest("Movie already in watchlist");

        watchlist.Movies.Add(movie);
        watchlist.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{tmdbId}/watchlist")]
    public async Task<IActionResult> RemoveFromWatchlist(int tmdbId)
    {
        Movie? movie = await _context.Movies.FirstOrDefaultAsync(m => m.TmdbId == tmdbId);
        if (movie == null)
            return NotFound("Movie not found");

        MediaList? watchlist = await _context.MediaLists.Include(l => l.Movies)
            .FirstOrDefaultAsync(l => l.IsSystem && l.Name == "Watchlist");
        if (watchlist == null)
            return NotFound("Watchlist not found");

        Movie? existing = watchlist.Movies.FirstOrDefault(m => m.TmdbId == tmdbId || m.Id == movie.Id);
        if (existing == null)
            return NotFound("Movie not in watchlist");

        watchlist.Movies.Remove(existing);
        watchlist.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id}/seen")]
    public async Task<ActionResult<Movie>> MarkAsSeen(int id, [FromBody] bool seen = true)
    {
        Movie? movie = await _context.Movies.FindAsync(id);
        if (movie == null)
            return NotFound("Movie not found");

        movie.Seen = seen;
        
        MediaList? seenList = await _context.MediaLists
            .Include(ml => ml.Movies)
            .FirstOrDefaultAsync(ml => ml.IsSystem && ml.Name == "Seen");

        if (seenList != null)
        {
            if (seen && !seenList.Movies.Any(m => m.Id == movie.Id))
            {
                seenList.Movies.Add(movie);
            }
            else if (!seen)
            {
                seenList.Movies.Remove(movie);
            }
        }

        await _context.SaveChangesAsync();
        return movie;
    }

    private static DateTime? ParseDate(string? dateString)
    {
        if (string.IsNullOrEmpty(dateString))
            return null;
        return DateTime.TryParse(dateString, out DateTime date) ? date : null;
    }

    [HttpGet("{tmdbId}/ratings")]
    public async Task<ActionResult<MediaRatingsDto?>> GetRatings(int tmdbId)
    {
        Movie? movie = await _context.Movies.FirstOrDefaultAsync(m => m.TmdbId == tmdbId);
        if (movie == null)
        {
            TMDbMovieResponse? tmdbMovie = await _tmdbService.GetMovieAsync(tmdbId);
            if (tmdbMovie == null)
            {
                return NotFound("Movie not found on TMDb");
            }

            movie = BuildMovieFromTmdb(tmdbMovie);
            _context.Movies.Add(movie);
            await _context.SaveChangesAsync();
        }

        if (HasStoredExternalRatings(movie))
        {
            return movie.ToRatings().ToDto();
        }

        int? releaseYear = movie.ReleaseDate?.Year;
        OmdbRatingsResult result = await _omdbService.GetExternalRatingsAsync(movie.ImdbId, movie.Title, releaseYear);
        if (result.Ratings == null)
        {
            return NoContent();
        }

        movie.ImdbRating = result.Ratings.ImdbRating;
        movie.ImdbVotes = result.Ratings.ImdbVotes;
        movie.RottenTomatoesRating = result.Ratings.RottenTomatoesRating;

        await _context.SaveChangesAsync();

        return movie.ToRatings().ToDto();
    }

    [HttpPost("{tmdbId}/refresh")]
    public async Task<ActionResult<MovieDto>> RefreshMovie(int tmdbId)
    {
        Movie? movie = await _context.Movies
            .Include(m => m.MediaLists)
            .FirstOrDefaultAsync(m => m.TmdbId == tmdbId);

        if (movie == null)
            return NotFound("Movie not found in database");

        // Fetch fresh data from TMDb
        TMDbMovieResponse? tmdbMovie = await _tmdbService.GetMovieAsync(tmdbId);
        if (tmdbMovie == null)
            return NotFound("Movie not found on TMDb");

        // Update TMDb fields
        movie.Title = tmdbMovie.Title;
        movie.OriginalTitle = tmdbMovie.OriginalTitle;
        movie.Overview = tmdbMovie.Overview;
        movie.Status = tmdbMovie.Status;
        movie.Tagline = tmdbMovie.Tagline;
        movie.PosterPath = tmdbMovie.PosterPath;
        movie.BackdropPath = tmdbMovie.BackdropPath;
        movie.VoteAverage = tmdbMovie.VoteAverage;
        movie.VoteCount = tmdbMovie.VoteCount;
        movie.Popularity = tmdbMovie.Popularity;
        movie.ReleaseDate = ParseDate(tmdbMovie.ReleaseDate);
        movie.Runtime = tmdbMovie.Runtime;
        movie.Budget = tmdbMovie.Budget;
        movie.Revenue = tmdbMovie.Revenue;
        movie.ImdbId = tmdbMovie.ImdbId;
        movie.Genres = string.Join(", ", tmdbMovie.Genres.Select(g => g.Name));
        movie.LastUpdated = DateTime.UtcNow;

        // Refresh OMDb ratings
        string queryTitle = string.IsNullOrWhiteSpace(movie.OriginalTitle) ? movie.Title : movie.OriginalTitle!;
        OmdbRatingsResult result = await _omdbService.GetExternalRatingsAsync(movie.ImdbId, queryTitle, movie.ReleaseDate?.Year);
        if (result.Ratings != null)
        {
            movie.ImdbRating = result.Ratings.ImdbRating;
            movie.ImdbVotes = result.Ratings.ImdbVotes;
            movie.RottenTomatoesRating = result.Ratings.RottenTomatoesRating;
        }

        await _context.SaveChangesAsync();
        return MapToDto(movie);
    }

    private static MovieDto MapToDto(Movie movie, DateTime? listAddedAt = null)
    {
        return new MovieDto
        {
            Id = movie.Id,
            TmdbId = movie.TmdbId,
            Title = movie.Title,
            OriginalTitle = movie.OriginalTitle,
            Overview = movie.Overview,
            Status = movie.Status,
            Tagline = movie.Tagline,
            PosterPath = movie.PosterPath,
            BackdropPath = movie.BackdropPath,
            VoteAverage = movie.VoteAverage,
            VoteCount = movie.VoteCount,
            Popularity = movie.Popularity,
            Ratings = movie.ToRatings().ToDto(),
            Liked = movie.Liked,
            Seen = movie.Seen,
            ReleaseDate = movie.ReleaseDate,
            Genres = movie.Genres,
            AddedAt = movie.AddedAt,
            LastUpdated = movie.LastUpdated,
            Runtime = movie.Runtime,
            Budget = movie.Budget,
            Revenue = movie.Revenue,
            ImdbId = movie.ImdbId,
            ListIds = movie.MediaLists.Select(ml => ml.Id).ToList(),
            ListAddedAt = listAddedAt
        };
    }

    private static Movie BuildMovieFromTmdb(TMDbMovieResponse tmdbMovie)
    {
        return new Movie
        {
            TmdbId = tmdbMovie.Id,
            Title = tmdbMovie.Title,
            OriginalTitle = tmdbMovie.OriginalTitle,
            Overview = tmdbMovie.Overview,
            Status = tmdbMovie.Status,
            Tagline = tmdbMovie.Tagline,
            PosterPath = tmdbMovie.PosterPath,
            BackdropPath = tmdbMovie.BackdropPath,
            VoteAverage = tmdbMovie.VoteAverage,
            VoteCount = tmdbMovie.VoteCount,
            Popularity = tmdbMovie.Popularity,
            ReleaseDate = ParseDate(tmdbMovie.ReleaseDate),
            Runtime = tmdbMovie.Runtime,
            Budget = tmdbMovie.Budget,
            Revenue = tmdbMovie.Revenue,
            ImdbId = tmdbMovie.ImdbId,
            Genres = string.Join(", ", tmdbMovie.Genres.Select(g => g.Name))
        };
    }

    private static bool HasStoredExternalRatings(Movie movie)
    {
        return movie.ImdbRating.HasValue || movie.ImdbVotes.HasValue || movie.RottenTomatoesRating.HasValue;
    }
}
