using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Services;

public class StatsService(ApiDbContext context)
{
    public async Task<StatsDto> GetStats()
    {
        // Dates d'ajout des films vus / épisodes vus : base commune des compteurs annuels et mensuels.
        IQueryable<DateTime> movieSeenDates = context.UserMedia
            .Where(m => m.Seen && m.MediaType == MediaType.Movie)
            .Select(m => m.AddedAt);

        IQueryable<DateTime> episodeSeenDates = context.UserEpisodes
            .Where(e => e.Seen)
            .Select(e => e.AddedAt);

        return new StatsDto
        {
            MoviesSeenCount = await context.UserMedia.CountAsync(m => m.Seen && m.MediaType == MediaType.Movie),
            ShowsSeenCount = await context.UserMedia.CountAsync(m => m.Seen && m.MediaType == MediaType.Show),
            EpisodesSeenCount = await context.UserEpisodes.CountAsync(e => e.Seen),
            TotalRuntimeMinutes = await context.UserMedia
                .Where(m => m.Seen && m.MediaType == MediaType.Movie && m.Runtime != null)
                .SumAsync(m => (int?)m.Runtime ?? 0),
            MoviesSeenByYear = await CountByYear(movieSeenDates),
            MoviesSeenByMonth = await CountByMonth(movieSeenDates),
            EpisodesSeenByYear = await CountByYear(episodeSeenDates),
            EpisodesSeenByMonth = await CountByMonth(episodeSeenDates),
        };
    }

    /// <summary>Nombre d'éléments par année, trié chronologiquement.</summary>
    private static Task<List<StatsYearBucket>> CountByYear(IQueryable<DateTime> dates) =>
        dates.GroupBy(d => d.Year)
            .Select(g => new StatsYearBucket { Year = g.Key, Count = g.Count() })
            .OrderBy(b => b.Year)
            .ToListAsync();

    /// <summary>Nombre d'éléments par mois, trié chronologiquement.</summary>
    private static Task<List<StatsMonthBucket>> CountByMonth(IQueryable<DateTime> dates) =>
        dates.GroupBy(d => new { d.Year, d.Month })
            .Select(g => new StatsMonthBucket { Year = g.Key.Year, Month = g.Key.Month, Count = g.Count() })
            .OrderBy(b => b.Year).ThenBy(b => b.Month)
            .ToListAsync();
}
