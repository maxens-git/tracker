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

    public MoviesController(ApiDbContext context, TMDbService tmdbService)
    {
        _context = context;
        _tmdbService = tmdbService;
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

            movie = new Movie
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

            _context.Movies.Add(movie);
            await _context.SaveChangesAsync();
        }

        return MapToDto(movie);
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

    private static MovieDto MapToDto(Movie movie)
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
            ListIds = movie.MediaLists.Select(ml => ml.Id).ToList()
        };
    }
}
