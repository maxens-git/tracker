using System.ComponentModel.DataAnnotations;
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
        [FromQuery] int page = 1, [FromQuery, RegularExpression("(?i)^(all|movie|show|tv)$")] string type = "all",
        [FromQuery] string? search = null) =>
        GetUserMediaItems(context.UserMedia.Where(m => m.Seen), page, type,
            q => q.OrderByDescending(m => m.WatchEvents.Max(w => (DateTime?)w.WatchedAt) ?? m.AddedAt)
                  .ThenByDescending(m => m.Id), search);

    [HttpGet("liked/items")]
    public Task<PaginatedResult<MediaListItemDto>> GetLikedItems(
        [FromQuery] int page = 1, [FromQuery, RegularExpression("(?i)^(all|movie|show|tv)$")] string type = "all",
        [FromQuery] string? search = null) =>
        GetUserMediaItems(context.UserMedia.Where(m => m.Liked), page, type, search: search);

    [HttpGet("watchlist/items")]
    public async Task<ActionResult<PaginatedResult<MediaListItemDto>>> GetWatchlistItems(
        [FromQuery] int page = 1, [FromQuery, RegularExpression("(?i)^(all|movie|show|tv)$")] string type = "all",
        [FromQuery] string? search = null)
    {
        MediaList? watchlist = await userMediaService.FindWatchlist();

        if (watchlist == null)
            return MediaListService.Paginate(new List<MediaListItemDto>(), page, 0);

        return await mediaListService.GetListItemsPaginated(watchlist.Id, page, type, search);
    }

    // ── Custom list item endpoints ─────────────────────────────────────────

    [HttpGet("{id:int}/items")]
    public async Task<ActionResult<PaginatedResult<MediaListItemDto>>> GetItems(
        int id, [FromQuery] int page = 1, [FromQuery, RegularExpression("(?i)^(all|movie|show|tv)$")] string type = "all",
        [FromQuery] string? search = null)
    {
        MediaList? list = await context.MediaLists.FindAsync(id);
        if (list == null)
            return NotFound("Liste introuvable");

        if (list.IsSystem && list.Name == SystemLists.Seen)
            return await GetSeenItems(page, type, search);
        if (list.IsSystem && list.Name == SystemLists.Liked)
            return await GetLikedItems(page, type, search);

        return await mediaListService.GetListItemsPaginated(id, page, type, search);
    }

    [HttpPost("{id:int}/items")]
    public async Task<IActionResult> AddItem(int id, [FromBody] AddListItemDto dto)
    {
        MediaList? list = await context.MediaLists.FindAsync(id);
        if (list == null)
            return NotFound("Liste introuvable");

        if (IsVirtualList(list))
            return BadRequest("Utilisez l'état vu ou aimé du média pour modifier cette liste.");

        MediaType mediaType = MediaTypeExtensions.Parse(dto.MediaType);

        bool alreadyIn = await context.MediaListItems
            .AnyAsync(i => i.MediaListId == id && i.TmdbId == dto.TmdbId && i.MediaType == mediaType);

        if (alreadyIn)
            return BadRequest("Déjà dans la liste");

        UserMedia um = await userMediaService.EnsureUserMedia(dto.TmdbId, mediaType, dto.PosterPath, genres: dto.Genres, title: dto.Title);

        context.MediaListItems.Add(new MediaListItem(id, dto.TmdbId, mediaType, dto.PosterPath ?? um.PosterPath, dto.Title ?? um.Title));

        list.UpdatedAt = DateTime.UtcNow;
        activityService.Log(ActivityType.AddedToList, dto.TmdbId, mediaType, dto.PosterPath ?? um.PosterPath, list.Id, list.Name);
        await context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}/items/{tmdbId}")]
    public async Task<IActionResult> RemoveItem(int id, [Range(1, int.MaxValue)] int tmdbId, [FromQuery, RegularExpression("(?i)^(movie|show|tv)$")] string type = "movie")
    {
        MediaList? list = await context.MediaLists.FindAsync(id);
        if (list != null && IsVirtualList(list))
            return BadRequest("Utilisez l'état vu ou aimé du média pour modifier cette liste.");

        MediaType mediaType = MediaTypeExtensions.Parse(type);

        MediaListItem? item = await context.MediaListItems
            .FirstOrDefaultAsync(i => i.MediaListId == id && i.TmdbId == tmdbId && i.MediaType == mediaType);

        if (item == null)
            return NotFound("Élément absent de la liste");

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
        if (string.IsNullOrWhiteSpace(dto.Name))
            return BadRequest("Le nom est requis.");

        string name = dto.Name.Trim();
        if (await context.MediaLists.AnyAsync(l => l.Name == name))
            return BadRequest("Une liste portant ce nom existe déjà.");

        MediaList list = new(name, dto.Description);

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
            return BadRequest("Impossible de modifier une liste système");

        string? name = dto.Name?.Trim();
        if (name != null && name.Length == 0)
            return BadRequest("Le nom est requis.");

        if (name != null && name != list.Name &&
            await context.MediaLists.AnyAsync(l => l.Name == name && l.Id != id))
            return BadRequest("Une liste portant ce nom existe déjà.");

        list.Name = name ?? list.Name;
        list.Description = dto.Description ?? list.Description;
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
            return BadRequest("Impossible de supprimer une liste système");

        context.MediaLists.Remove(list);
        await context.SaveChangesAsync();
        return NoContent();
    }

    /// <summary>Pagine une requête sur <see cref="UserMedia"/> (listes virtuelles "Vu"/"J'aime").</summary>
    private async Task<PaginatedResult<MediaListItemDto>> GetUserMediaItems(
        IQueryable<UserMedia> source, int page, string type,
        Func<IQueryable<UserMedia>, IOrderedQueryable<UserMedia>>? orderBy = null, string? search = null)
    {
        page = Math.Max(1, page);
        IQueryable<UserMedia> query = MediaListService.ApplySearchFilter(
            MediaListService.ApplyTypeFilter(source, type), search);
        int total = await query.CountAsync();
        long offset = ((long)page - 1) * MediaListService.PageSize;
        if (offset >= total)
            return MediaListService.Paginate([], page, total);

        orderBy ??= q => q.OrderByDescending(m => m.AddedAt).ThenByDescending(m => m.Id);

        List<UserMedia> items = await orderBy(query)
            .Skip((int)offset).Take(MediaListService.PageSize)
            .ToListAsync();

        return MediaListService.Paginate(items.Select(MediaListService.ToDto).ToList(), page, total);
    }

    private static bool IsVirtualList(MediaList list) =>
        list.IsSystem && list.Name is SystemLists.Seen or SystemLists.Liked;
}
