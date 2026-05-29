using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;

namespace Tracker.Services;

public class UserMediaService(ApiDbContext context)
{
    /// <summary>
    /// Récupère le <see cref="UserMedia"/> existant ou le crée. Met à jour le poster/runtime
    /// si fournis. La sauvegarde de la mise à jour est laissée à l'appelant.
    /// </summary>
    public async Task<UserMedia> EnsureUserMedia(int tmdbId, MediaType mediaType, string? posterPath = null, int? runtime = null)
    {
        UserMedia? um = await context.UserMedia
            .FirstOrDefaultAsync(m => m.TmdbId == tmdbId && m.MediaType == mediaType);

        if (um == null)
        {
            um = new UserMedia(tmdbId, mediaType, posterPath, runtime);
            context.UserMedia.Add(um);
            await context.SaveChangesAsync();
            return um;
        }

        if (posterPath != null) um.PosterPath = posterPath;
        if (runtime.HasValue) um.Runtime = runtime;
        return um;
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
            watchlist = new MediaList(SystemLists.Watchlist, icon: SystemLists.Icons[SystemLists.Watchlist], isSystem: true);
            context.MediaLists.Add(watchlist);
            await context.SaveChangesAsync();
        }

        return watchlist;
    }
}
