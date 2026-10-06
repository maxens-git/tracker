using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MediaController(
    ApiDbContext context,
    UserMediaService mediaService,
    ActivityService activityService,
    WatchHistoryService watchHistoryService) : ControllerBase
{
    [HttpGet("states")]
    public async Task<ActionResult<List<UserStateDto>>> GetStates([FromQuery] string tmdbIds, [FromQuery] string type = "movie")
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        List<int> ids = ParseTmdbIds(tmdbIds);

        if (ids.Count == 0)
            return new List<UserStateDto>();

        List<UserMedia> userMediaList = await context.UserMedia
            .Where(m => ids.Contains(m.TmdbId) && m.MediaType == mediaType)
            .ToListAsync();

        List<MediaListItem> listItems = await context.MediaListItems
            .Where(i => ids.Contains(i.TmdbId) && i.MediaType == mediaType)
            .ToListAsync();

        return ids.Select(tmdbId =>
        {
            UserMedia? um = userMediaList.FirstOrDefault(m => m.TmdbId == tmdbId);
            List<int> listIds = listItems.Where(i => i.TmdbId == tmdbId).Select(i => i.MediaListId).ToList();
            return new UserStateDto(tmdbId, um, listIds);
        }).ToList();
    }

    /// <summary>
    /// Bascule "vu"/"pas vu" : passer à vu ajoute 1 visionnage daté à maintenant, repasser à
    /// non-vu efface tout l'historique. Idempotent (aucun effet si l'état demandé est déjà atteint).
    /// Pour logger un visionnage à une date choisie ou consulter/éditer l'historique, voir les
    /// endpoints <c>/watches</c>.
    /// </summary>
    [HttpPost("{tmdbId}/seen")]
    public async Task<IActionResult> MarkSeen(int tmdbId, [FromQuery] string type, [FromBody] MarkSeenDto dto)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        UserMedia um = await mediaService.EnsureUserMedia(tmdbId, mediaType, dto.PosterPath, dto.Runtime, dto.Genres, dto.Title);

        if (dto.Seen && um.WatchCount == 0)
        {
            watchHistoryService.AddMovieWatch(um, DateTime.UtcNow);
            activityService.Log(ActivityType.MarkedSeen, tmdbId, mediaType, um.PosterPath);
        }
        else if (!dto.Seen && um.WatchCount > 0)
        {
            await watchHistoryService.ClearMovieWatches(um);
            activityService.Log(ActivityType.MarkedUnseen, tmdbId, mediaType, um.PosterPath);
        }

        await context.SaveChangesAsync();
        return Ok(new { tmdbId, seen = um.Seen, watchCount = um.WatchCount });
    }

    [HttpGet("{tmdbId}/watches")]
    public async Task<ActionResult<List<WatchEventDto>>> GetWatches(int tmdbId, [FromQuery] string type)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        UserMedia? um = await context.UserMedia.FirstOrDefaultAsync(m => m.TmdbId == tmdbId && m.MediaType == mediaType);
        if (um == null) return new List<WatchEventDto>();

        List<UserMediaWatchEvent> events = await watchHistoryService.GetMovieWatchHistory(um.Id);
        return events.Select(e => new WatchEventDto(e)).ToList();
    }

    /// <summary>Ajoute un visionnage à une date choisie par l'utilisateur (permet de logger un revisionnage passé).</summary>
    [HttpPost("{tmdbId}/watches")]
    public async Task<ActionResult<WatchEventDto>> AddWatch(int tmdbId, [FromQuery] string type, [FromBody] AddWatchDto dto)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        UserMedia um = await mediaService.EnsureUserMedia(tmdbId, mediaType, dto.PosterPath, dto.Runtime, dto.Genres, dto.Title);
        bool wasSeen = um.WatchCount > 0;

        UserMediaWatchEvent ev = watchHistoryService.AddMovieWatch(um, dto.WatchedAt);
        activityService.Log(wasSeen ? ActivityType.Rewatched : ActivityType.MarkedSeen, tmdbId, mediaType, um.PosterPath);

        await context.SaveChangesAsync();
        return Ok(new WatchEventDto(ev));
    }

    /// <summary>Supprime un visionnage précis de l'historique (édition, pas forcément un "je n'ai pas vu ce film").</summary>
    [HttpDelete("{tmdbId}/watches/{watchId}")]
    public async Task<IActionResult> DeleteWatch(int tmdbId, [FromQuery] string type, int watchId)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        UserMedia? um = await context.UserMedia.FirstOrDefaultAsync(m => m.TmdbId == tmdbId && m.MediaType == mediaType);
        if (um == null) return NotFound();

        bool removed = await watchHistoryService.RemoveMovieWatch(um, watchId);
        if (!removed) return NotFound("Visionnage introuvable");

        if (um.WatchCount == 0)
            activityService.Log(ActivityType.MarkedUnseen, tmdbId, mediaType, um.PosterPath);

        await context.SaveChangesAsync();
        return Ok(new { tmdbId, seen = um.Seen, watchCount = um.WatchCount });
    }

    [HttpPost("{tmdbId}/liked")]
    public async Task<IActionResult> MarkLiked(int tmdbId, [FromQuery] string type, [FromQuery] string? posterPath, [FromQuery] string? title, [FromBody] bool liked)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        UserMedia um = await mediaService.EnsureUserMedia(tmdbId, mediaType, posterPath, title: title);
        um.Liked = liked;
        activityService.Log(liked ? ActivityType.Liked : ActivityType.Unliked, tmdbId, mediaType, um.PosterPath);
        await context.SaveChangesAsync();
        return Ok(new { tmdbId, liked = um.Liked });
    }

    [HttpPost("{tmdbId}/watchlist")]
    public async Task<IActionResult> AddToWatchlist(int tmdbId, [FromQuery] string type, [FromBody] AddToWatchlistDto? dto)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        UserMedia um = await mediaService.EnsureUserMedia(tmdbId, mediaType, dto?.PosterPath, dto?.Runtime, dto?.Genres, dto?.Title);
        MediaList watchlist = await mediaService.EnsureWatchlist();

        bool alreadyIn = await context.MediaListItems
            .AnyAsync(i => i.MediaListId == watchlist.Id && i.TmdbId == tmdbId && i.MediaType == mediaType);

        if (alreadyIn)
            return BadRequest("Déjà dans la watchlist");

        context.MediaListItems.Add(new MediaListItem(watchlist.Id, tmdbId, mediaType, dto?.PosterPath ?? um.PosterPath, dto?.Title));
        watchlist.UpdatedAt = DateTime.UtcNow;
        activityService.Log(ActivityType.AddedToList, tmdbId, mediaType, dto?.PosterPath ?? um.PosterPath, watchlist.Id, watchlist.Name);
        await context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{tmdbId}/watchlist")]
    public async Task<IActionResult> RemoveFromWatchlist(int tmdbId, [FromQuery] string type)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        MediaList? watchlist = await mediaService.FindWatchlist();

        if (watchlist == null)
            return NotFound("Watchlist introuvable");

        MediaListItem? item = await context.MediaListItems
            .FirstOrDefaultAsync(i => i.MediaListId == watchlist.Id && i.TmdbId == tmdbId && i.MediaType == mediaType);

        if (item == null)
            return NotFound("Pas dans la watchlist");

        context.MediaListItems.Remove(item);
        watchlist.UpdatedAt = DateTime.UtcNow;
        activityService.Log(ActivityType.RemovedFromList, tmdbId, mediaType, item.PosterPath, watchlist.Id, watchlist.Name);
        await context.SaveChangesAsync();
        return NoContent();
    }

    /// <summary>Parse une liste d'identifiants TMDB séparés par des virgules, en ignorant les valeurs invalides.</summary>
    private static List<int> ParseTmdbIds(string tmdbIds) =>
        tmdbIds.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(s => int.TryParse(s, out int id) ? id : 0)
            .Where(id => id > 0)
            .ToList();
}
