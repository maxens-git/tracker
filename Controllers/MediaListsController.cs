using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MediaListsController : ControllerBase
{
    private readonly ApiDbContext _context;
    private readonly MediaListService _mediaListService;
    private readonly UserMediaService _userMediaService;

    public MediaListsController(ApiDbContext context, MediaListService mediaListService, UserMediaService userMediaService)
    {
        _context = context;
        _mediaListService = mediaListService;
        _userMediaService = userMediaService;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<MediaListSummaryDto>>> GetAll()
    {
        List<MediaList> lists = await _context.MediaLists
            .Include(ml => ml.Items)
            .ToListAsync();

        int seenMovies = await _context.UserMedia.CountAsync(m => m.Seen && m.MediaType == MediaType.Movie);
        int seenShows = await _context.UserMedia.CountAsync(m => m.Seen && m.MediaType == MediaType.Show);
        int likedMovies = await _context.UserMedia.CountAsync(m => m.Liked && m.MediaType == MediaType.Movie);
        int likedShows = await _context.UserMedia.CountAsync(m => m.Liked && m.MediaType == MediaType.Show);

        return lists.Select(ml =>
        {
            int count = ml.Name switch
            {
                "Seen" when ml.IsSystem => seenMovies + seenShows,
                "J'aime" when ml.IsSystem => likedMovies + likedShows,
                _ => ml.Items.Count
            };

            return new MediaListSummaryDto(ml, count);
        }).ToList();
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<MediaListSummaryDto>> GetById(int id)
    {
        MediaList? ml = await _context.MediaLists
            .Include(m => m.Items)
            .FirstOrDefaultAsync(m => m.Id == id);

        if (ml == null)
            return NotFound();

        int count = await _mediaListService.GetItemsCount(ml);

        return new MediaListSummaryDto(ml, count);
    }

    // ── Virtual system list endpoints ──────────────────────────────────────

    [HttpGet("seen/items")]
    public async Task<ActionResult<PaginatedResult<MediaListItemDto>>> GetSeenItems(
        [FromQuery] int page = 1, [FromQuery] string type = "all")
    {
        IQueryable<UserMedia> query = MediaListService.ApplyTypeFilter(_context.UserMedia.Where(m => m.Seen), type);
        int total = await query.CountAsync();
        List<UserMedia> items = await query.OrderByDescending(m => m.AddedAt)
            .Skip((page - 1) * MediaListService.PageSize).Take(MediaListService.PageSize)
            .ToListAsync();

        return MediaListService.Paginate(items.Select(MediaListService.ToDto).ToList(), page, total);
    }

    [HttpGet("liked/items")]
    public async Task<ActionResult<PaginatedResult<MediaListItemDto>>> GetLikedItems(
        [FromQuery] int page = 1, [FromQuery] string type = "all")
    {
        IQueryable<UserMedia> query = MediaListService.ApplyTypeFilter(_context.UserMedia.Where(m => m.Liked), type);
        int total = await query.CountAsync();
        List<UserMedia> items = await query.OrderByDescending(m => m.AddedAt)
            .Skip((page - 1) * MediaListService.PageSize).Take(MediaListService.PageSize)
            .ToListAsync();

        return MediaListService.Paginate(items.Select(MediaListService.ToDto).ToList(), page, total);
    }

    [HttpGet("watchlist/items")]
    public async Task<ActionResult<PaginatedResult<MediaListItemDto>>> GetWatchlistItems(
        [FromQuery] int page = 1, [FromQuery] string type = "all")
    {
        MediaList? watchlist = await _context.MediaLists
            .FirstOrDefaultAsync(l => l.IsSystem && l.Name == "Watchlist");

        if (watchlist == null)
            return MediaListService.Paginate(new List<MediaListItemDto>(), page, 0);

        return await _mediaListService.GetListItemsPaginated(watchlist.Id, page, type);
    }

    // ── Custom list item endpoints ─────────────────────────────────────────

    [HttpGet("{id:int}/items")]
    public async Task<ActionResult<PaginatedResult<MediaListItemDto>>> GetItems(
        int id, [FromQuery] int page = 1, [FromQuery] string type = "all")
    {
        bool exists = await _context.MediaLists.AnyAsync(ml => ml.Id == id);
        if (!exists)
            return NotFound("List not found");

        return await _mediaListService.GetListItemsPaginated(id, page, type);
    }

    [HttpPost("{id:int}/items")]
    public async Task<IActionResult> AddItem(int id, [FromBody] AddListItemDto dto)
    {
        MediaList? list = await _context.MediaLists.FindAsync(id);
        if (list == null)
            return NotFound("List not found");

        MediaType mediaType = UserMediaService.ParseMediaType(dto.MediaType);

        bool alreadyIn = await _context.MediaListItems
            .AnyAsync(i => i.MediaListId == id && i.TmdbId == dto.TmdbId && i.MediaType == mediaType);

        if (alreadyIn)
            return BadRequest("Already in list");

        UserMedia um = await _userMediaService.EnsureUserMedia(dto.TmdbId, mediaType, dto.PosterPath);

        _context.MediaListItems.Add(new MediaListItem(id, dto.TmdbId, mediaType, dto.PosterPath ?? um.PosterPath));

        list.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}/items/{tmdbId}")]
    public async Task<IActionResult> RemoveItem(int id, int tmdbId, [FromQuery] string type = "movie")
    {
        MediaType mediaType = UserMediaService.ParseMediaType(type);

        MediaListItem? item = await _context.MediaListItems
            .FirstOrDefaultAsync(i => i.MediaListId == id && i.TmdbId == tmdbId && i.MediaType == mediaType);

        if (item == null)
            return NotFound("Item not in list");

        MediaList? list = await _context.MediaLists.FindAsync(id);
        if (list != null) list.UpdatedAt = DateTime.UtcNow;

        _context.MediaListItems.Remove(item);
        await _context.SaveChangesAsync();
        return NoContent();
    }

    // ── List CRUD ──────────────────────────────────────────────────────────

    [HttpPost]
    public async Task<ActionResult<MediaListSummaryDto>> Create([FromBody] MediaListCreateDto dto)
    {
        MediaList list = new MediaList(dto.Name, dto.Description, dto.Icon);

        _context.MediaLists.Add(list);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = list.Id }, new MediaListSummaryDto(list, 0));
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] MediaListUpdateDto dto)
    {
        MediaList? list = await _context.MediaLists.FindAsync(id);

        if (list == null)
            return NotFound();

        if (list.IsSystem)
            return BadRequest("Cannot modify system list");

        list.Name = dto.Name ?? list.Name;
        list.Description = dto.Description ?? list.Description;
        list.Icon = dto.Icon ?? list.Icon;
        list.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        MediaList? list = await _context.MediaLists.FindAsync(id);

        if (list == null)
            return NotFound();

        if (list.IsSystem)
            return BadRequest("Cannot delete system list");

        _context.MediaLists.Remove(list);
        await _context.SaveChangesAsync();
        return NoContent();
    }
}
