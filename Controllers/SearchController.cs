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
public class SearchController : ControllerBase
{
    private readonly TMDbService _tmdbService;
    private readonly ApiDbContext _context;

    public SearchController(TMDbService tmdbService, ApiDbContext context)
    {
        _tmdbService = tmdbService;
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<TMDbSearchResponse>> Search(
        [FromQuery] string query,
        [FromQuery] int page = 1,
        [FromQuery] int take = 20)
    {
        if (string.IsNullOrWhiteSpace(query))
            return BadRequest("Query is required");

        TMDbSearchResponse? result = await _tmdbService.SearchMultiAsync(query, page);

        if (result == null)
            return StatusCode(500, "TMDb request failed");

        int safeTake = Math.Clamp(take, 1, 20);

        result.Results = result.Results
            .Where(r => r.MediaType == "movie" || r.MediaType == "tv")
            .Take(safeTake)
            .ToList();

        await ApplySeenStatusAsync(result.Results);

        return result;
    }

    [HttpGet("suggestions")]
    public async Task<ActionResult<IEnumerable<TMDbSearchResult>>> GetSuggestions(
        [FromQuery] string query,
        [FromQuery] int take = 5)
    {
        if (string.IsNullOrWhiteSpace(query))
            return BadRequest("Query is required");

        TMDbSearchResponse? result = await _tmdbService.SearchMultiAsync(query, 1);

        if (result == null)
            return StatusCode(500, "TMDb request failed");

        int safeTake = Math.Clamp(take, 1, 10);
        List<TMDbSearchResult> suggestions = result.Results
            .Where(r => r.MediaType == "movie" || r.MediaType == "tv")
            .OrderByDescending(r => r.Popularity)
            .Take(safeTake)
            .ToList();

        await ApplySeenStatusAsync(suggestions);

        return suggestions;
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
