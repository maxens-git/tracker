using Microsoft.EntityFrameworkCore;
using System.Text.Json;
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
            TotalRuntimeMinutes = await TotalRuntimeMinutes(),
            MoviesSeenByYear = await CountByYear(movieSeenDates),
            MoviesSeenByMonth = await CountByMonth(movieSeenDates),
            EpisodesSeenByYear = await CountByYear(episodeSeenDates),
            EpisodesSeenByMonth = await CountByMonth(episodeSeenDates),
            FavoriteGenres = await FavoriteGenres(),
        };
    }

    /// <summary>Genres les plus vus, calculés sur les films et séries marqués comme vus.</summary>
    private async Task<List<StatsGenreBucket>> FavoriteGenres()
    {
        List<string> genrePayloads = await context.UserMedia
            .Where(m => m.Seen && m.GenreNamesJson != null && m.GenreNamesJson != "")
            .Select(m => m.GenreNamesJson!)
            .ToListAsync();

        Dictionary<string, int> counts = new(StringComparer.OrdinalIgnoreCase);
        Dictionary<string, string> labels = new(StringComparer.OrdinalIgnoreCase);

        foreach (string payload in genrePayloads)
        {
            List<string>? names = DeserializeGenreNames(payload);
            if (names == null) continue;

            foreach (string name in names.Select(n => n.Trim()).Where(n => n.Length > 0).Distinct(StringComparer.OrdinalIgnoreCase))
            {
                counts[name] = counts.GetValueOrDefault(name) + 1;
                labels.TryAdd(name, name);
            }
        }

        int total = genrePayloads.Count;
        if (total == 0) return new List<StatsGenreBucket>();

        return counts
            .OrderByDescending(kv => kv.Value)
            .ThenBy(kv => labels[kv.Key])
            // .Take(7) // troncature désactivée temporairement
            .Select(kv => new StatsGenreBucket
            {
                Name = labels[kv.Key],
                Count = kv.Value,
                Percentage = (int)Math.Round(kv.Value * 100d / total),
            })
            .ToList();
    }

    /// <summary>Durée totale vue : films + épisodes, avec fallback pour séries sans épisodes détaillés.</summary>
    private async Task<int> TotalRuntimeMinutes()
    {
        int moviesRuntime = await context.UserMedia
            .Where(m => m.Seen && m.MediaType == MediaType.Movie && m.Runtime != null)
            .SumAsync(m => (int?)m.Runtime ?? 0);

        int episodesRuntime = await context.UserEpisodes
            .Where(e => e.Seen && e.Runtime != null)
            .SumAsync(e => (int?)e.Runtime ?? 0);

        IQueryable<int> showsWithSeenEpisodes = context.UserEpisodes
            .Where(e => e.Seen)
            .Select(e => e.ShowTmdbId)
            .Distinct();

        int showFallbackRuntime = await context.UserMedia
            .Where(m => m.Seen
                        && m.MediaType == MediaType.Show
                        && m.Runtime != null
                        && !showsWithSeenEpisodes.Contains(m.TmdbId))
            .SumAsync(m => (int?)m.Runtime ?? 0);

        return moviesRuntime + episodesRuntime + showFallbackRuntime;
    }

    private static List<string>? DeserializeGenreNames(string payload)
    {
        try
        {
            return JsonSerializer.Deserialize<List<string>>(payload);
        }
        catch (JsonException)
        {
            return null;
        }
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
