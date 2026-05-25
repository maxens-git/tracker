using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MediaController : ControllerBase
{
    private readonly ApiDbContext _context;
    private readonly UserMediaService _mediaService;

    public MediaController(ApiDbContext context, UserMediaService mediaService)
    {
        _context = context;
        _mediaService = mediaService;
    }

    [HttpGet("states")]
    public async Task<ActionResult<List<UserStateDto>>> GetStates([FromQuery] string tmdbIds, [FromQuery] string type = "movie")
    {
        MediaType mediaType = UserMediaService.ParseMediaType(type);
        List<int> ids = tmdbIds.Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(s => int.TryParse(s.Trim(), out int id) ? id : -1)
            .Where(id => id > 0)
            .ToList();

        if (ids.Count == 0)
            return new List<UserStateDto>();

        List<UserMedia> userMediaList = await _context.UserMedia
            .Where(m => ids.Contains(m.TmdbId) && m.MediaType == mediaType)
            .ToListAsync();

        List<MediaListItem> listItems = await _context.MediaListItems
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
        MediaType mediaType = UserMediaService.ParseMediaType(type);
        UserMedia um = await _mediaService.EnsureUserMedia(tmdbId, mediaType);
        um.Seen = dto.Seen;
        if (dto.Runtime.HasValue)
            um.Runtime = dto.Runtime;
        await _context.SaveChangesAsync();
        return Ok(new { tmdbId, seen = um.Seen });
    }

    [HttpPost("{tmdbId}/liked")]
    public async Task<IActionResult> MarkLiked(int tmdbId, [FromQuery] string type, [FromBody] bool liked)
    {
        MediaType mediaType = UserMediaService.ParseMediaType(type);
        UserMedia um = await _mediaService.EnsureUserMedia(tmdbId, mediaType);
        um.Liked = liked;
        await _context.SaveChangesAsync();
        return Ok(new { tmdbId, liked = um.Liked });
    }

    [HttpPost("{tmdbId}/watchlist")]
    public async Task<IActionResult> AddToWatchlist(int tmdbId, [FromQuery] string type, [FromBody] AddToWatchlistDto? dto)
    {
        MediaType mediaType = UserMediaService.ParseMediaType(type);
        UserMedia um = await _mediaService.EnsureUserMedia(tmdbId, mediaType, dto?.PosterPath, dto?.Runtime);

        MediaList watchlist = await _mediaService.EnsureWatchlist();

        bool alreadyIn = await _context.MediaListItems
            .AnyAsync(i => i.MediaListId == watchlist.Id && i.TmdbId == tmdbId && i.MediaType == mediaType);

        if (alreadyIn)
            return BadRequest("Already in watchlist");

        _context.MediaListItems.Add(new MediaListItem(watchlist.Id, tmdbId, mediaType, dto?.PosterPath ?? um.PosterPath));

        watchlist.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{tmdbId}/watchlist")]
    public async Task<IActionResult> RemoveFromWatchlist(int tmdbId, [FromQuery] string type)
    {
        MediaType mediaType = UserMediaService.ParseMediaType(type);
        MediaList? watchlist = await _context.MediaLists
            .FirstOrDefaultAsync(l => l.IsSystem && l.Name == "Watchlist");

        if (watchlist == null)
            return NotFound("Watchlist not found");

        MediaListItem? item = await _context.MediaListItems
            .FirstOrDefaultAsync(i => i.MediaListId == watchlist.Id && i.TmdbId == tmdbId && i.MediaType == mediaType);

        if (item == null)
            return NotFound("Not in watchlist");

        _context.MediaListItems.Remove(item);
        watchlist.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

}
