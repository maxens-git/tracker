using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models.TMDbResponses;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class TrendsController : ControllerBase
{
    private readonly TMDbService _tmdbService;
    private readonly ApiDbContext _context;

    public TrendsController(TMDbService tmdbService, ApiDbContext context)
    {
        _tmdbService = tmdbService;
        _context = context;
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

        trending.Results ??= new();
        popularMovies.Results ??= new();
        popularShows.Results ??= new();
        topRated.Results ??= new();

        SetMediaType(popularMovies.Results, "movie");
        SetMediaType(popularShows.Results, "tv");
        SetMediaType(topRated.Results, "movie");
        if (trending.Results != null && trending.Results.Count > 0)
        {
            foreach (TMDbSearchResult item in trending.Results)
            {
                if (string.IsNullOrWhiteSpace(item.MediaType))
                {
                    item.MediaType = "movie";
                }
            }
        }

        TrendingHomeDto result = new TrendingHomeDto
        {
            FeaturedItem = trending.Results.FirstOrDefault(),
            TrendingWeek = trending.Results.Take(20).ToList(),
            PopularMovies = popularMovies.Results.Take(20).ToList(),
            PopularShows = popularShows.Results.Take(20).ToList(),
            TopRated = topRated.Results.Take(20).ToList()
        };

        await ApplySeenStatusAsync(result);

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

        result.Results ??= new();

        await ApplySeenStatusAsync(result.Results);

        return result;
    }

    [HttpGet("popular/movies")]
    public async Task<ActionResult<TMDbSearchResponse>> GetPopularMovies([FromQuery] int page = 1)
    {
        TMDbSearchResponse? result = await _tmdbService.GetPopularMoviesAsync(page);

        if (result == null)
            return StatusCode(500, "TMDb request failed");

        result.Results ??= new();

        SetMediaType(result.Results, "movie");

        await ApplySeenStatusAsync(result.Results);

        return result;
    }

    [HttpGet("popular/shows")]
    public async Task<ActionResult<TMDbSearchResponse>> GetPopularShows([FromQuery] int page = 1)
    {
        TMDbSearchResponse? result = await _tmdbService.GetPopularShowsAsync(page);

        if (result == null)
            return StatusCode(500, "TMDb request failed");

        result.Results ??= new();

        SetMediaType(result.Results, "tv");

        await ApplySeenStatusAsync(result.Results);

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

        result.Results ??= new();

        SetMediaType(result.Results, mediaType);

        await ApplySeenStatusAsync(result.Results);

        return result;
    }

    private static void SetMediaType(List<TMDbSearchResult> items, string mediaType)
    {
        if (items == null || items.Count == 0)
            return;

        foreach (TMDbSearchResult item in items)
        {
            if (string.IsNullOrWhiteSpace(item.MediaType))
            {
                item.MediaType = mediaType;
            }
        }
    }

    private async Task ApplySeenStatusAsync(TrendingHomeDto homeDto)
    {
        List<TMDbSearchResult> items = new();

        if (homeDto.FeaturedItem != null)
            items.Add(homeDto.FeaturedItem);

        items.AddRange(homeDto.TrendingWeek);
        items.AddRange(homeDto.PopularMovies);
        items.AddRange(homeDto.PopularShows);
        items.AddRange(homeDto.TopRated);

        await ApplySeenStatusAsync(items);
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
