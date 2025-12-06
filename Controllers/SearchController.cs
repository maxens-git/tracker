using Microsoft.AspNetCore.Mvc;
using Tracker.Models.TMDbResponses;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SearchController : ControllerBase
{
    private readonly TMDbService _tmdbService;

    public SearchController(TMDbService tmdbService)
    {
        _tmdbService = tmdbService;
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

        return suggestions;
    }
}
