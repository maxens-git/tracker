using Microsoft.AspNetCore.Mvc;
using Tracker.Models.TMDbResponses;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SimilarController : ControllerBase
{
    private readonly TMDbService _tmdbService;

    public SimilarController(TMDbService tmdbService)
    {
        _tmdbService = tmdbService;
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

        return response;
    }
}
