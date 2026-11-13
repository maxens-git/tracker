using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Services;

public class UserMediaService(ApiDbContext context)
{
    /// <summary>
    /// Récupère le <see cref="UserMedia"/> existant ou le crée. Met à jour le poster/runtime
    /// si fournis. La création et les modifications sont sauvegardées par l'appelant.
    /// </summary>
    public async Task<UserMedia> EnsureUserMedia(
        int tmdbId,
        MediaType mediaType,
        string? posterPath = null,
        int? runtime = null,
        IEnumerable<MediaGenreDto>? genres = null,
        string? title = null)
    {
        UserMedia? um = context.UserMedia.Local
            .FirstOrDefault(m => m.TmdbId == tmdbId && m.MediaType == mediaType)
            ?? await context.UserMedia.FirstOrDefaultAsync(m => m.TmdbId == tmdbId && m.MediaType == mediaType);

        string? genreNamesJson = SerializeGenreNames(genres);

        if (um == null)
        {
            um = new UserMedia(tmdbId, mediaType, posterPath, runtime, genreNamesJson, title);
            context.UserMedia.Add(um);
            return um;
        }

        if (posterPath != null) um.PosterPath = posterPath;
        if (runtime.HasValue) um.Runtime = runtime;
        if (genreNamesJson != null) um.GenreNamesJson = genreNamesJson;
        if (title != null) um.Title = title;
        return um;
    }

    private static string? SerializeGenreNames(IEnumerable<MediaGenreDto>? genres)
    {
        if (genres == null) return null;

        List<string> names = genres
            .Select(g => g?.Name?.Trim() ?? string.Empty)
            .Where(name => name.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        return names.Count > 0 ? JsonSerializer.Serialize(names) : null;
    }

    /// <summary>Retourne la watchlist système ou <c>null</c> si elle n'existe pas encore.</summary>
    public async Task<MediaList?> FindWatchlist() =>
        context.MediaLists.Local.FirstOrDefault(l => l.IsSystem && l.Name == SystemLists.Watchlist)
        ?? await context.MediaLists.FirstOrDefaultAsync(l => l.IsSystem && l.Name == SystemLists.Watchlist);

    /// <summary>Retourne la watchlist système, en la créant si nécessaire.</summary>
    public async Task<MediaList> EnsureWatchlist()
    {
        MediaList? watchlist = await FindWatchlist();

        if (watchlist == null)
        {
            watchlist = new MediaList(SystemLists.Watchlist, isSystem: true);
            context.MediaLists.Add(watchlist);
            await context.SaveChangesAsync();
        }

        return watchlist;
    }
}
