using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;

namespace Tracker.Services;

/// <summary>
/// Point d'entrée unique pour ajouter/retirer des visionnages datés, en maintenant
/// <see cref="UserMedia.Seen"/>/<see cref="UserMedia.WatchCount"/> (et l'équivalent épisode)
/// en synchronisation. Ne sauvegarde pas : laissé au contrôleur appelant (même convention
/// que <see cref="ActivityService.Log"/> et <see cref="UserMediaService.EnsureUserMedia"/>).
/// </summary>
public class WatchHistoryService(ApiDbContext context)
{
    // ── Films / séries (UserMedia) ─────────────────────────────────────────

    public UserMediaWatchEvent AddMovieWatch(UserMedia um, DateTime watchedAt)
    {
        UserMediaWatchEvent ev = new(um.Id, watchedAt) { UserMedia = um };
        context.UserMediaWatchEvents.Add(ev);
        um.WatchCount++;
        um.Seen = true;
        return ev;
    }

    public async Task<bool> RemoveMovieWatch(UserMedia um, int watchEventId)
    {
        UserMediaWatchEvent? ev = await context.UserMediaWatchEvents
            .FirstOrDefaultAsync(w => w.Id == watchEventId && w.UserMediaId == um.Id);

        if (ev == null) return false;

        context.UserMediaWatchEvents.Remove(ev);
        um.WatchCount = Math.Max(0, um.WatchCount - 1);
        um.Seen = um.WatchCount > 0;
        return true;
    }

    public Task<List<UserMediaWatchEvent>> GetMovieWatchHistory(int userMediaId) =>
        context.UserMediaWatchEvents
            .Where(w => w.UserMediaId == userMediaId)
            .OrderByDescending(w => w.WatchedAt)
            .ThenByDescending(w => w.Id)
            .ToListAsync();

    public async Task ClearMovieWatches(UserMedia um)
    {
        List<UserMediaWatchEvent> events = await context.UserMediaWatchEvents
            .Where(w => w.UserMediaId == um.Id)
            .ToListAsync();

        events.AddRange(context.UserMediaWatchEvents.Local
            .Where(w => w.UserMedia == um && !events.Contains(w)));
        context.UserMediaWatchEvents.RemoveRange(events);
        um.WatchCount = 0;
        um.Seen = false;
    }

    // ── Épisodes (UserEpisode) ──────────────────────────────────────────────

    public UserEpisodeWatchEvent AddEpisodeWatch(UserEpisode ep, DateTime watchedAt)
    {
        UserEpisodeWatchEvent ev = new(ep.Id, watchedAt) { UserEpisode = ep };
        context.UserEpisodeWatchEvents.Add(ev);
        ep.WatchCount++;
        ep.Seen = true;
        return ev;
    }

    public async Task<bool> RemoveEpisodeWatch(UserEpisode ep, int watchEventId)
    {
        UserEpisodeWatchEvent? ev = await context.UserEpisodeWatchEvents
            .FirstOrDefaultAsync(w => w.Id == watchEventId && w.UserEpisodeId == ep.Id);

        if (ev == null) return false;

        context.UserEpisodeWatchEvents.Remove(ev);
        ep.WatchCount = Math.Max(0, ep.WatchCount - 1);
        ep.Seen = ep.WatchCount > 0;
        return true;
    }

    public Task<List<UserEpisodeWatchEvent>> GetEpisodeWatchHistory(int userEpisodeId) =>
        context.UserEpisodeWatchEvents
            .Where(w => w.UserEpisodeId == userEpisodeId)
            .OrderByDescending(w => w.WatchedAt)
            .ThenByDescending(w => w.Id)
            .ToListAsync();

    public async Task ClearEpisodeWatches(UserEpisode ep)
    {
        List<UserEpisodeWatchEvent> events = await context.UserEpisodeWatchEvents
            .Where(w => w.UserEpisodeId == ep.Id)
            .ToListAsync();

        events.AddRange(context.UserEpisodeWatchEvents.Local
            .Where(w => w.UserEpisode == ep && !events.Contains(w)));
        context.UserEpisodeWatchEvents.RemoveRange(events);
        ep.WatchCount = 0;
        ep.Seen = false;
    }
}
