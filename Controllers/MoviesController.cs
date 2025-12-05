using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.Models.TMDbResponses;
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
    public async Task<ActionResult<Movie>> GetByTmdbId(int tmdbId)
    {
        Movie? movie = await _context.Movies.FirstOrDefaultAsync(m => m.TmdbId == tmdbId);

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

        return movie;
    }

    private static DateTime? ParseDate(string? dateString)
    {
        if (string.IsNullOrEmpty(dateString))
            return null;
        return DateTime.TryParse(dateString, out DateTime date) ? date : null;
    }
}
