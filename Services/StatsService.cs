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

        return AggregateGenres(genrePayloads);
    }

    /// <summary>Répartition des genres pour chaque liste (Vu, J'aime, Watchlist, listes custom).</summary>
    public async Task<List<StatsListGenresDto>> GenresByList()
    {
        List<MediaList> lists = await context.MediaLists.ToListAsync();

        List<StatsListGenresDto> result = new();
        foreach (MediaList list in lists)
        {
            List<string> payloads = await GenrePayloadsForList(list);
            result.Add(new StatsListGenresDto
            {
                ListId = list.Id,
                Name = list.Name,
                IsSystem = list.IsSystem,
                Genres = AggregateGenres(payloads),
            });
        }

        return result;
    }

    /// <summary>
    /// Payloads de genres (<see cref="UserMedia.GenreNamesJson"/>) des médias d'une liste.
    /// Réplique la logique de dispatch de <c>MediaListsController.GetAll</c> : les listes
    /// système Vu/J'aime sont virtuelles (flags sur <see cref="UserMedia"/>), les autres
    /// (Watchlist + custom) sont matérialisées via <see cref="MediaListItem"/>.
    /// </summary>
    private Task<List<string>> GenrePayloadsForList(MediaList list)
    {
        if (list.IsSystem && list.Name == SystemLists.Seen)
            return context.UserMedia
                .Where(m => m.Seen && m.GenreNamesJson != null && m.GenreNamesJson != "")
                .Select(m => m.GenreNamesJson!)
                .ToListAsync();

        if (list.IsSystem && list.Name == SystemLists.Liked)
            return context.UserMedia
                .Where(m => m.Liked && m.GenreNamesJson != null && m.GenreNamesJson != "")
                .Select(m => m.GenreNamesJson!)
                .ToListAsync();

        return (from item in context.MediaListItems
                where item.MediaListId == list.Id
                join um in context.UserMedia
                    on new { item.TmdbId, item.MediaType } equals new { um.TmdbId, um.MediaType }
                where um.GenreNamesJson != null && um.GenreNamesJson != ""
                select um.GenreNamesJson!)
            .ToListAsync();
    }

    /// <summary>Agrège des payloads JSON de noms de genres en buckets triés avec pourcentages.</summary>
    private static List<StatsGenreBucket> AggregateGenres(List<string> genrePayloads)
    {
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
