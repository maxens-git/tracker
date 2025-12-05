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
    public async Task<ActionResult<TMDbSearchResponse>> Search([FromQuery] string query, [FromQuery] int page = 1)
    {
        if (string.IsNullOrWhiteSpace(query))
            return BadRequest("Query is required");

        TMDbSearchResponse? result = await _tmdbService.SearchMultiAsync(query, page);

        if (result == null)
            return StatusCode(500, "TMDb request failed");

        result.Results = result.Results
            .Where(r => r.MediaType == "movie" || r.MediaType == "tv")
            .ToList();

        return result;
    }
}
