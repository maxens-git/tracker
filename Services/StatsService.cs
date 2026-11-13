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
        // Dates réelles de chaque visionnage (revisionnages inclus) : base des compteurs annuels et mensuels.
        IQueryable<DateTime> movieWatchDates = context.UserMediaWatchEvents
            .Join(context.UserMedia.Where(m => m.MediaType == MediaType.Movie),
                w => w.UserMediaId, m => m.Id, (w, m) => w.WatchedAt);

        IQueryable<DateTime> episodeWatchDates = context.UserEpisodeWatchEvents
            .Select(w => w.WatchedAt);

        return new StatsDto
        {
            MoviesSeenCount = await context.UserMedia.CountAsync(m => m.Seen && m.MediaType == MediaType.Movie),
            ShowsSeenCount = await context.UserMedia.CountAsync(m => m.Seen && m.MediaType == MediaType.Show),
            EpisodesSeenCount = await context.UserEpisodes.CountAsync(e => e.Seen),
            MoviesWatchCount = await movieWatchDates.CountAsync(),
            EpisodesWatchCount = await episodeWatchDates.CountAsync(),
            TotalRuntimeMinutes = await TotalRuntimeMinutes(),
            MoviesSeenByYear = await CountByYear(movieWatchDates),
            MoviesSeenByMonth = await CountByMonth(movieWatchDates),
            EpisodesSeenByYear = await CountByYear(episodeWatchDates),
            EpisodesSeenByMonth = await CountByMonth(episodeWatchDates),
            FavoriteGenres = await FavoriteGenres(),
            MostRewatched = await MostRewatched(),
        };
    }

    /// <summary>Films, séries et épisodes revus au moins une fois, triés par nombre de visionnages décroissant.</summary>
    private async Task<List<MostRewatchedDto>> MostRewatched()
    {
        List<MostRewatchedDto> movies = await context.UserMedia
            .Where(m => m.WatchCount >= 2)
            .Select(m => new MostRewatchedDto
            {
                TmdbId = m.TmdbId,
                MediaType = m.MediaType == MediaType.Movie ? "movie" : "show",
                Title = m.Title,
                PosterPath = m.PosterPath,
                WatchCount = m.WatchCount,
            })
            .ToListAsync();

        List<UserEpisode> rewatchedEpisodes = await context.UserEpisodes
            .Where(e => e.WatchCount >= 2)
            .ToListAsync();

        Dictionary<int, UserMedia> shows = await context.UserMedia
            .Where(m => m.MediaType == MediaType.Show)
            .ToDictionaryAsync(m => m.TmdbId);

        List<MostRewatchedDto> episodes = rewatchedEpisodes.Select(e =>
        {
            shows.TryGetValue(e.ShowTmdbId, out UserMedia? show);
            return new MostRewatchedDto
            {
                TmdbId = e.ShowTmdbId,
                MediaType = "show",
                Title = show?.Title,
                PosterPath = show?.PosterPath,
                SeasonNumber = e.SeasonNumber,
                EpisodeNumber = e.EpisodeNumber,
                WatchCount = e.WatchCount,
            };
        }).ToList();

        return movies.Concat(episodes)
            .OrderByDescending(d => d.WatchCount)
            .Take(10)
            .ToList();
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

            foreach (string name in names.Where(n => !string.IsNullOrWhiteSpace(n)).Select(n => n.Trim()).Distinct(StringComparer.OrdinalIgnoreCase))
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

    /// <summary>Durée totale vue (revisionnages comptés autant de fois) : films + épisodes, avec fallback pour séries sans épisodes détaillés.</summary>
    private async Task<int> TotalRuntimeMinutes()
    {
        int moviesRuntime = await context.UserMedia
            .Where(m => m.MediaType == MediaType.Movie && m.Runtime != null)
            .SumAsync(m => (m.Runtime ?? 0) * m.WatchCount);

        int episodesRuntime = await context.UserEpisodes
            .Where(e => e.Runtime != null)
            .SumAsync(e => (e.Runtime ?? 0) * e.WatchCount);

        IQueryable<int> showsWithSeenEpisodes = context.UserEpisodes
            .Where(e => e.WatchCount > 0)
            .Select(e => e.ShowTmdbId)
            .Distinct();

        int showFallbackRuntime = await context.UserMedia
            .Where(m => m.MediaType == MediaType.Show
                        && m.Runtime != null
                        && !showsWithSeenEpisodes.Contains(m.TmdbId))
            .SumAsync(m => (m.Runtime ?? 0) * m.WatchCount);

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
