using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Services;

public class StatsService(ApiDbContext context)
{
    public async Task<StatsDto> GetStats()
    {
        int moviesSeen = await context.UserMedia.CountAsync(m => m.Seen && m.MediaType == MediaType.Movie);
        int showsSeen = await context.UserMedia.CountAsync(m => m.Seen && m.MediaType == MediaType.Show);
        int episodesSeen = await context.UserEpisodes.CountAsync(e => e.Seen);
        int moviesMinutes = await context.UserMedia
            .Where(m => m.Seen && m.MediaType == MediaType.Movie && m.Runtime != null)
            .SumAsync(m => (int?)m.Runtime ?? 0);

        return new StatsDto
        {
            MoviesSeenCount = moviesSeen,
            ShowsSeenCount = showsSeen,
            EpisodesSeenCount = episodesSeen,
            TotalRuntimeMinutes = moviesMinutes,
            MoviesSeenByYear = await context.UserMedia
                .Where(m => m.Seen && m.MediaType == MediaType.Movie)
                .GroupBy(m => m.AddedAt.Year)
                .Select(g => new StatsYearBucket { Year = g.Key, Count = g.Count() })
                .OrderBy(g => g.Year)
                .ToListAsync(),
            MoviesSeenByMonth = await context.UserMedia
                .Where(m => m.Seen && m.MediaType == MediaType.Movie)
                .GroupBy(m => new { m.AddedAt.Year, m.AddedAt.Month })
                .Select(g => new StatsMonthBucket { Year = g.Key.Year, Month = g.Key.Month, Count = g.Count() })
                .OrderBy(g => g.Year).ThenBy(g => g.Month)
                .ToListAsync(),
            EpisodesSeenByYear = await context.UserEpisodes
                .Where(e => e.Seen)
                .GroupBy(e => e.AddedAt.Year)
                .Select(g => new StatsYearBucket { Year = g.Key, Count = g.Count() })
                .OrderBy(g => g.Year)
                .ToListAsync(),
            EpisodesSeenByMonth = await context.UserEpisodes
                .Where(e => e.Seen)
                .GroupBy(e => new { e.AddedAt.Year, e.AddedAt.Month })
                .Select(g => new StatsMonthBucket { Year = g.Key.Year, Month = g.Key.Month, Count = g.Count() })
                .OrderBy(g => g.Year).ThenBy(g => g.Month)
                .ToListAsync()
        };
    }
}
