using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;

namespace Tracker.Services;

public class UserMediaService(ApiDbContext context)
{
    public async Task<UserMedia> EnsureUserMedia(int tmdbId, MediaType mediaType, string? posterPath = null, int? runtime = null)
    {
        UserMedia? um = await context.UserMedia
            .FirstOrDefaultAsync(m => m.TmdbId == tmdbId && m.MediaType == mediaType);

        if (um == null)
        {
            um = new UserMedia(tmdbId, mediaType, posterPath, runtime);
            context.UserMedia.Add(um);
            await context.SaveChangesAsync();
        }
        else
        {
            if (posterPath != null) um.PosterPath = posterPath;
            if (runtime.HasValue) um.Runtime = runtime;
        }

        return um;
    }

    public static MediaType ParseMediaType(string type) =>
        type.ToLower() == "show" || type.ToLower() == "tv" ? MediaType.Show : MediaType.Movie;

    public async Task<MediaList> EnsureWatchlist()
    {
        MediaList? watchlist = await context.MediaLists
            .FirstOrDefaultAsync(l => l.IsSystem && l.Name == "Watchlist");

        if (watchlist == null)
        {
            watchlist = new MediaList("Watchlist", icon: "🎬", isSystem: true);
            context.MediaLists.Add(watchlist);
            await context.SaveChangesAsync();
        }

        return watchlist;
    }
}
