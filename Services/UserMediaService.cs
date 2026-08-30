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
    /// si fournis. La sauvegarde de la mise à jour est laissée à l'appelant.
    /// </summary>
    public async Task<UserMedia> EnsureUserMedia(
        int tmdbId,
        MediaType mediaType,
        string? posterPath = null,
        int? runtime = null,
        IEnumerable<MediaGenreDto>? genres = null)
    {
        UserMedia? um = await context.UserMedia
            .FirstOrDefaultAsync(m => m.TmdbId == tmdbId && m.MediaType == mediaType);

        string? genreNamesJson = SerializeGenreNames(genres);

        if (um == null)
        {
            um = new UserMedia(tmdbId, mediaType, posterPath, runtime, genreNamesJson);
            context.UserMedia.Add(um);
            await context.SaveChangesAsync();
            return um;
        }

        if (posterPath != null) um.PosterPath = posterPath;
        if (runtime.HasValue) um.Runtime = runtime;
        if (genreNamesJson != null) um.GenreNamesJson = genreNamesJson;
        return um;
    }

    private static string? SerializeGenreNames(IEnumerable<MediaGenreDto>? genres)
    {
        if (genres == null) return null;

        List<string> names = genres
            .Select(g => g.Name.Trim())
            .Where(name => name.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        return names.Count > 0 ? JsonSerializer.Serialize(names) : null;
    }

    /// <summary>Retourne la watchlist système ou <c>null</c> si elle n'existe pas encore.</summary>
    public Task<MediaList?> FindWatchlist() =>
        context.MediaLists.FirstOrDefaultAsync(l => l.IsSystem && l.Name == SystemLists.Watchlist);

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
