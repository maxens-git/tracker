using Microsoft.AspNetCore.Mvc;
using Tracker.Models.TMDbResponses;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TrendsController : ControllerBase
{
    private readonly TMDbService _tmdbService;

    public TrendsController(TMDbService tmdbService)
    {
        _tmdbService = tmdbService;
    }

    [HttpGet("home")]
    public async Task<ActionResult<TrendingHomeDto>> GetHomeData()
    {
        TMDbSearchResponse? trending = await _tmdbService.GetTrendingAsync("all", "week");
        TMDbSearchResponse? popularMovies = await _tmdbService.GetPopularMoviesAsync();
        TMDbSearchResponse? popularShows = await _tmdbService.GetPopularShowsAsync();
        TMDbSearchResponse? topRated = await _tmdbService.GetTopRatedAsync("movie");

        if (trending == null || popularMovies == null || popularShows == null || topRated == null)
            return StatusCode(500, "TMDb request failed");

        TrendingHomeDto result = new TrendingHomeDto
        {
            FeaturedItem = trending.Results.FirstOrDefault(),
            TrendingWeek = trending.Results.Take(20).ToList(),
            PopularMovies = popularMovies.Results.Take(20).ToList(),
            PopularShows = popularShows.Results.Take(20).ToList(),
            TopRated = topRated.Results.Take(20).ToList()
        };

        return result;
    }

    [HttpGet("trending/{mediaType}")]
    public async Task<ActionResult<TMDbSearchResponse>> GetTrending(string mediaType = "all", [FromQuery] string timeWindow = "week")
    {
        if (mediaType != "all" && mediaType != "movie" && mediaType != "tv")
            return BadRequest("mediaType must be: all, movie, or tv");

        if (timeWindow != "day" && timeWindow != "week")
            return BadRequest("timeWindow must be: day or week");

        TMDbSearchResponse? result = await _tmdbService.GetTrendingAsync(mediaType, timeWindow);

        if (result == null)
            return StatusCode(500, "TMDb request failed");

        return result;
    }

    [HttpGet("popular/movies")]
    public async Task<ActionResult<TMDbSearchResponse>> GetPopularMovies([FromQuery] int page = 1)
    {
        TMDbSearchResponse? result = await _tmdbService.GetPopularMoviesAsync(page);

        if (result == null)
            return StatusCode(500, "TMDb request failed");

        return result;
    }

    [HttpGet("popular/shows")]
    public async Task<ActionResult<TMDbSearchResponse>> GetPopularShows([FromQuery] int page = 1)
    {
        TMDbSearchResponse? result = await _tmdbService.GetPopularShowsAsync(page);

        if (result == null)
            return StatusCode(500, "TMDb request failed");

        return result;
    }

    [HttpGet("top-rated")]
    public async Task<ActionResult<TMDbSearchResponse>> GetTopRated([FromQuery] string mediaType = "movie", [FromQuery] int page = 1)
    {
        if (mediaType != "movie" && mediaType != "tv")
            return BadRequest("mediaType must be: movie or tv");

        TMDbSearchResponse? result = await _tmdbService.GetTopRatedAsync(mediaType, page);

        if (result == null)
            return StatusCode(500, "TMDb request failed");

        return result;
    }
}
