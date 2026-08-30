using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;

namespace Tracker;

public static class DbSeeder
{
    public static async Task SeedSystemListsAsync(ApiDbContext context)
    {
        foreach (string name in SystemLists.Names)
        {
            bool exists = await context.MediaLists.AnyAsync(l => l.Name == name);
            if (!exists)
            {
                context.MediaLists.Add(new MediaList(name, isSystem: true));
            }
        }

        await context.SaveChangesAsync();
    }

    /// <summary>
    /// Importe les données exportées de JustWatch dans le schéma léger, une seule fois
    /// (si aucune donnée utilisateur n'existe encore).
    /// - justwatch_seenlist.json   → films marqués vus / épisodes de séries vus
    /// - justwatch_likelist.json   → UserMedia.Liked
    /// - justwatch_watchlist.json  → MediaListItem sur la liste système "Watchlist"
    ///
    /// Les séries contiennent désormais leurs saisons et épisodes avec un état "vu / pas vu".
    /// On stocke un <see cref="UserEpisode"/> par épisode vu, puis on dérive :
    ///   - une saison est vue si tous ses épisodes le sont ;
    ///   - une série (<see cref="UserMedia.Seen"/>) est vue si toutes ses saisons le sont.
    /// </summary>
    public static async Task SeedFromJustWatchAsync(ApiDbContext context, string contentRoot)
    {
        // Idempotent : ne seed qu'une base vierge pour ne pas écraser les choix de l'utilisateur.
        if (await context.UserMedia.AnyAsync())
            return;

        string dataDir = Path.Combine(contentRoot, "Seed", "Data");
        List<JustWatchEntry> seen = ReadEntries(Path.Combine(dataDir, "justwatch_seenlist.json"));
        List<JustWatchEntry> liked = ReadEntries(Path.Combine(dataDir, "justwatch_likelist.json"));
        List<JustWatchEntry> watchlist = ReadEntries(Path.Combine(dataDir, "justwatch_watchlist.json"));

        if (seen.Count == 0 && liked.Count == 0 && watchlist.Count == 0)
            return;

        // UserMedia fusionnés par (tmdbId, type) : un média peut être à la fois vu et aimé.
        Dictionary<(int, MediaType), UserMedia> mediaByKey = new();

        UserMedia GetOrCreate(int tmdbId, MediaType type, DateTime addedAt)
        {
            var key = (tmdbId, type);
            if (!mediaByKey.TryGetValue(key, out UserMedia? um))
            {
                um = new UserMedia(tmdbId, type) { AddedAt = addedAt };
                mediaByKey[key] = um;
            }
            return um;
        }

        // État des épisodes fusionné entre toutes les listes : un épisode vu dans n'importe quelle
        // liste compte comme vu. Clé : showTmdbId → (saison, épisode) → état.
        Dictionary<int, Dictionary<(int Season, int Episode), EpisodeState>> episodesByShow = new();
        // Nombre d'épisodes par saison (selon JustWatch), pour savoir si une saison est complète.
        Dictionary<(int Show, int Season), int> seasonSizes = new();

        void MergeEpisodes(JustWatchEntry e, int showTmdbId)
        {
            if (e.Seasons == null) return;

            if (!episodesByShow.TryGetValue(showTmdbId, out var perShow))
                perShow = episodesByShow[showTmdbId] = new();

            foreach (JustWatchSeason s in e.Seasons)
            {
                int size = s.EpisodeCount ?? s.Episodes?.Count ?? 0;
                var sizeKey = (showTmdbId, s.SeasonNumber);
                if (!seasonSizes.TryGetValue(sizeKey, out int prev) || size > prev)
                    seasonSizes[sizeKey] = size;

                if (s.Episodes == null) continue;
                foreach (JustWatchEpisode ep in s.Episodes)
                {
                    var key = (s.SeasonNumber, ep.EpisodeNumber);
                    DateTime? at = ep.SeenAt?.ToUniversalTime();
                    if (perShow.TryGetValue(key, out EpisodeState? state))
                    {
                        state.Seen |= ep.Seen;
                        state.SeenAt ??= at;
                    }
                    else
                    {
                        perShow[key] = new EpisodeState { Seen = ep.Seen, SeenAt = at };
                    }
                }
            }
        }

        // Séries explicitement marquées vues : leur statut "vu" fait autorité quelles que soient
        // les saisons listées par JustWatch.
        HashSet<int> seenShowIds = new();

        foreach (JustWatchEntry e in seen)
            if (TryParse(e, out int id, out MediaType type, out DateTime at))
            {
                UserMedia um = GetOrCreate(id, type, at);
                if (type == MediaType.Show)
                {
                    seenShowIds.Add(id);
                    MergeEpisodes(e, id);
                }
                else
                {
                    um.Seen = true;
                }
            }

        foreach (JustWatchEntry e in liked)
            if (TryParse(e, out int id, out MediaType type, out DateTime at))
            {
                GetOrCreate(id, type, at).Liked = true;
                if (type == MediaType.Show) MergeEpisodes(e, id);
            }

        // Les entrées de watchlist ont aussi besoin d'un UserMedia (cohérence avec l'ajout via l'API),
        // et apportent la progression épisode des séries en cours de visionnage.
        foreach (JustWatchEntry e in watchlist)
            if (TryParse(e, out int id, out MediaType type, out DateTime at))
            {
                GetOrCreate(id, type, at);
                if (type == MediaType.Show) MergeEpisodes(e, id);
            }

        // Dérive le statut "vu" de chaque série : vue si explicitement marquée vue, ou si toutes
        // ses saisons connues sont entièrement vues (tous leurs épisodes vus).
        foreach (UserMedia um in mediaByKey.Values.Where(m => m.MediaType == MediaType.Show))
        {
            bool allSeasonsSeen = false;
            if (episodesByShow.TryGetValue(um.TmdbId, out var eps))
            {
                var seasons = eps.Keys.Select(k => k.Season).Distinct().ToList();
                allSeasonsSeen = seasons.Count > 0 && seasons.All(season =>
                {
                    int seenCount = eps.Count(kv => kv.Key.Season == season && kv.Value.Seen);
                    int total = seasonSizes.TryGetValue((um.TmdbId, season), out int t) ? t : seenCount;
                    return total > 0 && seenCount >= total;
                });
            }
            um.Seen = seenShowIds.Contains(um.TmdbId) || allSeasonsSeen;
        }

        // Un UserEpisode par épisode vu (l'absence de ligne = épisode non vu, cohérent avec l'API).
        foreach (var (showId, eps) in episodesByShow)
            foreach (var (key, state) in eps)
                if (state.Seen)
                    context.UserEpisodes.Add(
                        new UserEpisode(showId, key.Season, key.Episode, seen: true)
                        {
                            AddedAt = state.SeenAt ?? DateTime.UtcNow
                        });

        context.UserMedia.AddRange(mediaByKey.Values);

        // Items de la watchlist rattachés à la liste système.
        MediaList? wl = await context.MediaLists
            .FirstOrDefaultAsync(l => l.IsSystem && l.Name == SystemLists.Watchlist);

        if (wl != null)
        {
            HashSet<(int, MediaType)> added = new();
            foreach (JustWatchEntry e in watchlist)
            {
                if (!TryParse(e, out int id, out MediaType type, out DateTime at)) continue;
                if (!added.Add((id, type))) continue;
                context.MediaListItems.Add(new MediaListItem(wl.Id, id, type) { AddedAt = at });
            }
            wl.UpdatedAt = DateTime.UtcNow;
        }

        await context.SaveChangesAsync();
    }

    private static List<JustWatchEntry> ReadEntries(string path)
    {
        if (!File.Exists(path))
            return new List<JustWatchEntry>();

        using FileStream stream = File.OpenRead(path);
        return JsonSerializer.Deserialize<List<JustWatchEntry>>(stream) ?? new List<JustWatchEntry>();
    }

    private static bool TryParse(JustWatchEntry entry, out int tmdbId, out MediaType mediaType, out DateTime addedAt)
    {
        mediaType = string.Equals(entry.Type, "SHOW", StringComparison.OrdinalIgnoreCase)
            ? MediaType.Show
            : MediaType.Movie;
        addedAt = entry.CreatedAt?.ToUniversalTime() ?? DateTime.UtcNow;
        return int.TryParse(entry.TmdbId, out tmdbId) && tmdbId > 0;
    }

    /// <summary>État "vu" mutable d'un épisode, fusionné entre les listes.</summary>
    private sealed class EpisodeState
    {
        public bool Seen;
        public DateTime? SeenAt;
    }

    private sealed record JustWatchEntry(
        [property: JsonPropertyName("type")] string? Type,
        [property: JsonPropertyName("tmdbId")] string? TmdbId,
        [property: JsonPropertyName("createdAt")] DateTime? CreatedAt,
        [property: JsonPropertyName("seasons")] List<JustWatchSeason>? Seasons
    );

    private sealed record JustWatchSeason(
        [property: JsonPropertyName("seasonNumber")] int SeasonNumber,
        [property: JsonPropertyName("episodeCount")] int? EpisodeCount,
        [property: JsonPropertyName("episodes")] List<JustWatchEpisode>? Episodes
    );

    private sealed record JustWatchEpisode(
        [property: JsonPropertyName("episodeNumber")] int EpisodeNumber,
        [property: JsonPropertyName("seen")] bool Seen,
        [property: JsonPropertyName("seenAt")] DateTime? SeenAt
    );
}
