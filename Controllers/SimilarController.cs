using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models.TMDbResponses;
using Tracker.Services;

namespace Tracker.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class SimilarController : ControllerBase
{
    private readonly TMDbService _tmdbService;
    private readonly ApiDbContext _context;

    public SimilarController(TMDbService tmdbService, ApiDbContext context)
    {
        _tmdbService = tmdbService;
        _context = context;
    }

    [HttpGet("movies/{tmdbId}")]
    public async Task<ActionResult<TMDbSearchResponse>> GetSimilarMovies(
        int tmdbId,
        [FromQuery] int page = 1,
        [FromQuery] int take = 20)
    {
        TMDbSearchResponse? response = await _tmdbService.GetSimilarMoviesAsync(tmdbId, page);
        if (response == null)
            return StatusCode(502, "TMDb request failed");

        int safeTake = Math.Clamp(take, 1, 20);
        response.Results = response.Results
            .Select(r =>
            {
                if (string.IsNullOrWhiteSpace(r.MediaType))
                    r.MediaType = "movie";
                return r;
            })
            .Take(safeTake)
            .ToList();

        await ApplySeenStatusAsync(response.Results);

        return response;
    }

    [HttpGet("shows/{tmdbId}")]
    public async Task<ActionResult<TMDbSearchResponse>> GetSimilarShows(
        int tmdbId,
        [FromQuery] int page = 1,
        [FromQuery] int take = 20)
    {
        TMDbSearchResponse? response = await _tmdbService.GetSimilarShowsAsync(tmdbId, page);
        if (response == null)
            return StatusCode(502, "TMDb request failed");

        int safeTake = Math.Clamp(take, 1, 20);
        response.Results = response.Results
            .Select(r =>
            {
                if (string.IsNullOrWhiteSpace(r.MediaType))
                    r.MediaType = "tv";
                return r;
            })
            .Take(safeTake)
            .ToList();

        await ApplySeenStatusAsync(response.Results);

        return response;
    }

    private async Task ApplySeenStatusAsync(IEnumerable<TMDbSearchResult> results)
    {
        List<TMDbSearchResult> items = results.ToList();
        if (items.Count == 0)
            return;

        List<int> movieTmdbIds = items
            .Where(i => string.Equals(i.MediaType, "movie", StringComparison.OrdinalIgnoreCase))
            .Select(i => i.Id)
            .Distinct()
            .ToList();

        List<int> showTmdbIds = items
            .Where(i => string.Equals(i.MediaType, "tv", StringComparison.OrdinalIgnoreCase))
            .Select(i => i.Id)
            .Distinct()
            .ToList();

        Dictionary<int, bool> movieSeen = await _context.Movies
            .Where(m => movieTmdbIds.Contains(m.TmdbId))
            .ToDictionaryAsync(m => m.TmdbId, m => m.Seen);

        Dictionary<int, bool> showSeen = await _context.Shows
            .Where(s => showTmdbIds.Contains(s.TmdbId))
            .ToDictionaryAsync(s => s.TmdbId, s => s.Seen);

        foreach (TMDbSearchResult item in items)
        {
            if (string.Equals(item.MediaType, "movie", StringComparison.OrdinalIgnoreCase) && movieSeen.TryGetValue(item.Id, out bool movieIsSeen))
            {
                item.Seen = movieIsSeen;
            }
            else if (string.Equals(item.MediaType, "tv", StringComparison.OrdinalIgnoreCase) && showSeen.TryGetValue(item.Id, out bool showIsSeen))
            {
                item.Seen = showIsSeen;
            }
            else
            {
                item.Seen = false;
            }
        }
    }
}
