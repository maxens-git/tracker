using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.ModelsDTO;

namespace Tracker.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class StatsController : ControllerBase
{
    private readonly ApiDbContext _context;

    public StatsController(ApiDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<StatsDto>> Get()
    {
        int moviesSeen = await _context.Movies.CountAsync(m => m.Seen);
        int showsSeen = await _context.Shows.CountAsync(s => s.Seen);
        int episodesSeen = await _context.Episodes.CountAsync(e => e.Seen);

        int moviesMinutes = await _context.Movies
            .Where(m => m.Seen)
            .SumAsync(m => (int?)m.Runtime ?? 0);

        int episodesMinutes = await _context.Episodes
            .Where(e => e.Seen)
            .SumAsync(e => (int?)e.Runtime ?? 0);

        StatsDto dto = new StatsDto
        {
            MoviesSeenCount = moviesSeen,
            ShowsSeenCount = showsSeen,
            EpisodesSeenCount = episodesSeen,
            TotalRuntimeMinutes = moviesMinutes + episodesMinutes,
            MoviesSeenByYear = await _context.Movies
                .Where(m => m.Seen)
                .GroupBy(m => m.AddedAt.Year)
                .Select(g => new StatsYearBucket { Year = g.Key, Count = g.Count() })
                .OrderBy(g => g.Year)
                .ToListAsync(),
            MoviesSeenByMonth = await _context.Movies
                .Where(m => m.Seen)
                .GroupBy(m => new { m.AddedAt.Year, m.AddedAt.Month })
                .Select(g => new StatsMonthBucket { Year = g.Key.Year, Month = g.Key.Month, Count = g.Count() })
                .OrderBy(g => g.Year).ThenBy(g => g.Month)
                .ToListAsync(),
            ShowsSeenByYear = await _context.Shows
                .Where(s => s.Seen)
                .GroupBy(s => s.AddedAt.Year)
                .Select(g => new StatsYearBucket { Year = g.Key, Count = g.Count() })
                .OrderBy(g => g.Year)
                .ToListAsync(),
            ShowsSeenByMonth = await _context.Shows
                .Where(s => s.Seen)
                .GroupBy(s => new { s.AddedAt.Year, s.AddedAt.Month })
                .Select(g => new StatsMonthBucket { Year = g.Key.Year, Month = g.Key.Month, Count = g.Count() })
                .OrderBy(g => g.Year).ThenBy(g => g.Month)
                .ToListAsync()
        };

        return dto;
    }
}
