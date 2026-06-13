using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MediaListsController(
    ApiDbContext context,
    MediaListService mediaListService,
    UserMediaService userMediaService,
    ActivityService activityService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IEnumerable<MediaListSummaryDto>>> GetAll()
    {
        List<MediaList> lists = await context.MediaLists
            .Include(ml => ml.Items)
            .ToListAsync();

        int seenCount = await context.UserMedia.CountAsync(m => m.Seen);
        int likedCount = await context.UserMedia.CountAsync(m => m.Liked);

        return lists.Select(ml =>
        {
            int count = (ml.IsSystem, ml.Name) switch
            {
                (true, SystemLists.Seen) => seenCount,
                (true, SystemLists.Liked) => likedCount,
                _ => ml.Items.Count
            };

            return new MediaListSummaryDto(ml, count);
        }).ToList();
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<MediaListSummaryDto>> GetById(int id)
    {
        MediaList? ml = await context.MediaLists
            .Include(m => m.Items)
            .FirstOrDefaultAsync(m => m.Id == id);

        if (ml == null)
            return NotFound();

        int count = await mediaListService.GetItemsCount(ml);

        return new MediaListSummaryDto(ml, count);
    }

    // ── Virtual system list endpoints ──────────────────────────────────────

    [HttpGet("seen/items")]
    public Task<PaginatedResult<MediaListItemDto>> GetSeenItems(
        [FromQuery] int page = 1, [FromQuery] string type = "all") =>
        GetUserMediaItems(context.UserMedia.Where(m => m.Seen), page, type);

    [HttpGet("liked/items")]
    public Task<PaginatedResult<MediaListItemDto>> GetLikedItems(
        [FromQuery] int page = 1, [FromQuery] string type = "all") =>
        GetUserMediaItems(context.UserMedia.Where(m => m.Liked), page, type);

    [HttpGet("watchlist/items")]
    public async Task<ActionResult<PaginatedResult<MediaListItemDto>>> GetWatchlistItems(
        [FromQuery] int page = 1, [FromQuery] string type = "all")
    {
        MediaList? watchlist = await userMediaService.FindWatchlist();

        if (watchlist == null)
            return MediaListService.Paginate(new List<MediaListItemDto>(), page, 0);

        return await mediaListService.GetListItemsPaginated(watchlist.Id, page, type);
    }

    // ── Custom list item endpoints ─────────────────────────────────────────

    [HttpGet("{id:int}/items")]
    public async Task<ActionResult<PaginatedResult<MediaListItemDto>>> GetItems(
        int id, [FromQuery] int page = 1, [FromQuery] string type = "all")
    {
        bool exists = await context.MediaLists.AnyAsync(ml => ml.Id == id);
        if (!exists)
            return NotFound("List not found");

        return await mediaListService.GetListItemsPaginated(id, page, type);
    }

    [HttpPost("{id:int}/items")]
    public async Task<IActionResult> AddItem(int id, [FromBody] AddListItemDto dto)
    {
        MediaList? list = await context.MediaLists.FindAsync(id);
        if (list == null)
            return NotFound("List not found");

        MediaType mediaType = MediaTypeExtensions.Parse(dto.MediaType);

        bool alreadyIn = await context.MediaListItems
            .AnyAsync(i => i.MediaListId == id && i.TmdbId == dto.TmdbId && i.MediaType == mediaType);

        if (alreadyIn)
            return BadRequest("Already in list");

        UserMedia um = await userMediaService.EnsureUserMedia(dto.TmdbId, mediaType, dto.PosterPath);

        context.MediaListItems.Add(new MediaListItem(id, dto.TmdbId, mediaType, dto.PosterPath ?? um.PosterPath));

        list.UpdatedAt = DateTime.UtcNow;
        activityService.Log(ActivityType.AddedToList, dto.TmdbId, mediaType, dto.PosterPath ?? um.PosterPath, list.Id, list.Name);
        await context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}/items/{tmdbId}")]
    public async Task<IActionResult> RemoveItem(int id, int tmdbId, [FromQuery] string type = "movie")
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);

        MediaListItem? item = await context.MediaListItems
            .FirstOrDefaultAsync(i => i.MediaListId == id && i.TmdbId == tmdbId && i.MediaType == mediaType);

        if (item == null)
            return NotFound("Item not in list");

        MediaList? list = await context.MediaLists.FindAsync(id);
        if (list != null) list.UpdatedAt = DateTime.UtcNow;

        context.MediaListItems.Remove(item);
        activityService.Log(ActivityType.RemovedFromList, tmdbId, mediaType, item.PosterPath, id, list?.Name);
        await context.SaveChangesAsync();
        return NoContent();
    }

    // ── List CRUD ──────────────────────────────────────────────────────────

    [HttpPost]
    public async Task<ActionResult<MediaListSummaryDto>> Create([FromBody] MediaListCreateDto dto)
    {
        MediaList list = new(dto.Name, dto.Description, dto.Icon);

        context.MediaLists.Add(list);
        await context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = list.Id }, new MediaListSummaryDto(list, 0));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] MediaListUpdateDto dto)
    {
        MediaList? list = await context.MediaLists.FindAsync(id);

        if (list == null)
            return NotFound();

        if (list.IsSystem)
            return BadRequest("Cannot modify system list");

        list.Name = dto.Name ?? list.Name;
        list.Description = dto.Description ?? list.Description;
        list.Icon = dto.Icon ?? list.Icon;
        list.UpdatedAt = DateTime.UtcNow;

        await context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        MediaList? list = await context.MediaLists.FindAsync(id);

        if (list == null)
            return NotFound();

        if (list.IsSystem)
            return BadRequest("Cannot delete system list");

        context.MediaLists.Remove(list);
        await context.SaveChangesAsync();
        return NoContent();
    }

    /// <summary>Pagine une requête sur <see cref="UserMedia"/> (listes virtuelles "Vu"/"J'aime").</summary>
    private async Task<PaginatedResult<MediaListItemDto>> GetUserMediaItems(
        IQueryable<UserMedia> source, int page, string type)
    {
        IQueryable<UserMedia> query = MediaListService.ApplyTypeFilter(source, type);
        int total = await query.CountAsync();

        List<UserMedia> items = await query
            .OrderByDescending(m => m.AddedAt)
            .Skip((page - 1) * MediaListService.PageSize).Take(MediaListService.PageSize)
            .ToListAsync();

        return MediaListService.Paginate(items.Select(MediaListService.ToDto).ToList(), page, total);
    }
}
