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
                SystemLists.Icons.TryGetValue(name, out string? icon);
                context.MediaLists.Add(new MediaList(name, icon: icon, isSystem: true));
            }
        }

        await context.SaveChangesAsync();
    }

    /// <summary>
    /// Importe les données exportées de JustWatch dans le schéma léger, une seule fois
    /// (si aucune donnée utilisateur n'existe encore).
    /// - export_justwatch.json          → UserMedia.Seen
    /// - export_justwatch_likelist.json  → UserMedia.Liked
    /// - export_justwatch_watchlist.json → MediaListItem sur la liste système "Watchlist"
    /// </summary>
    public static async Task SeedFromJustWatchAsync(ApiDbContext context, string contentRoot)
    {
        // Idempotent : ne seed qu'une base vierge pour ne pas écraser les choix de l'utilisateur.
        if (await context.UserMedia.AnyAsync())
            return;

        string dataDir = Path.Combine(contentRoot, "Seed", "Data");
        List<JustWatchEntry> seen = ReadEntries(Path.Combine(dataDir, "export_justwatch.json"));
        List<JustWatchEntry> liked = ReadEntries(Path.Combine(dataDir, "export_justwatch_likelist.json"));
        List<JustWatchEntry> watchlist = ReadEntries(Path.Combine(dataDir, "export_justwatch_watchlist.json"));

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

        foreach (JustWatchEntry e in seen)
            if (TryParse(e, out int id, out MediaType type, out DateTime at))
                GetOrCreate(id, type, at).Seen = true;

        foreach (JustWatchEntry e in liked)
            if (TryParse(e, out int id, out MediaType type, out DateTime at))
                GetOrCreate(id, type, at).Liked = true;

        // Les entrées de watchlist ont aussi besoin d'un UserMedia (cohérence avec l'ajout via l'API).
        foreach (JustWatchEntry e in watchlist)
            if (TryParse(e, out int id, out MediaType type, out DateTime at))
                GetOrCreate(id, type, at);

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

    private sealed record JustWatchEntry(
        [property: JsonPropertyName("type")] string? Type,
        [property: JsonPropertyName("tmdbId")] string? TmdbId,
        [property: JsonPropertyName("createdAt")] DateTime? CreatedAt
    );
}
