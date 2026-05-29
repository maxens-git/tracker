using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MediaController(ApiDbContext context, UserMediaService mediaService) : ControllerBase
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

    [HttpPost("{tmdbId}/seen")]
    public async Task<IActionResult> MarkSeen(int tmdbId, [FromQuery] string type, [FromBody] MarkSeenDto dto)
    {
        UserMedia um = await mediaService.EnsureUserMedia(tmdbId, MediaTypeExtensions.Parse(type));
        um.Seen = dto.Seen;
        if (dto.Runtime.HasValue)
            um.Runtime = dto.Runtime;
        await context.SaveChangesAsync();
        return Ok(new { tmdbId, seen = um.Seen });
    }

    [HttpPost("{tmdbId}/liked")]
    public async Task<IActionResult> MarkLiked(int tmdbId, [FromQuery] string type, [FromBody] bool liked)
    {
        UserMedia um = await mediaService.EnsureUserMedia(tmdbId, MediaTypeExtensions.Parse(type));
        um.Liked = liked;
        await context.SaveChangesAsync();
        return Ok(new { tmdbId, liked = um.Liked });
    }

    [HttpPost("{tmdbId}/watchlist")]
    public async Task<IActionResult> AddToWatchlist(int tmdbId, [FromQuery] string type, [FromBody] AddToWatchlistDto? dto)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        UserMedia um = await mediaService.EnsureUserMedia(tmdbId, mediaType, dto?.PosterPath, dto?.Runtime);
        MediaList watchlist = await mediaService.EnsureWatchlist();

        bool alreadyIn = await context.MediaListItems
            .AnyAsync(i => i.MediaListId == watchlist.Id && i.TmdbId == tmdbId && i.MediaType == mediaType);

        if (alreadyIn)
            return BadRequest("Already in watchlist");

        context.MediaListItems.Add(new MediaListItem(watchlist.Id, tmdbId, mediaType, dto?.PosterPath ?? um.PosterPath));
        watchlist.UpdatedAt = DateTime.UtcNow;
        await context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{tmdbId}/watchlist")]
    public async Task<IActionResult> RemoveFromWatchlist(int tmdbId, [FromQuery] string type)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        MediaList? watchlist = await mediaService.FindWatchlist();

        if (watchlist == null)
            return NotFound("Watchlist not found");

        MediaListItem? item = await context.MediaListItems
            .FirstOrDefaultAsync(i => i.MediaListId == watchlist.Id && i.TmdbId == tmdbId && i.MediaType == mediaType);

        if (item == null)
            return NotFound("Not in watchlist");

        context.MediaListItems.Remove(item);
        watchlist.UpdatedAt = DateTime.UtcNow;
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
