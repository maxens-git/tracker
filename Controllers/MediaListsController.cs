using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MediaListsController : ControllerBase
{
    private readonly ApiDbContext _context;
    private const int PageSize = 20;

    public MediaListsController(ApiDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<MediaListSummaryDto>>> GetAll()
    {
        List<MediaListSummaryDto> lists = await _context.MediaLists
            .Select(ml => new MediaListSummaryDto
            {
                Id = ml.Id,
                Name = ml.Name,
                Description = ml.Description,
                Icon = ml.Icon,
                IsSystem = ml.IsSystem,
                MoviesCount = ml.Movies.Count,
                ShowsCount = ml.Shows.Count,
                CreatedAt = ml.CreatedAt,
                UpdatedAt = ml.UpdatedAt
            })
            .ToListAsync();

        return lists;
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<MediaListSummaryDto>> GetById(int id)
    {
        MediaListSummaryDto? mediaList = await _context.MediaLists
            .Where(ml => ml.Id == id)
            .Select(ml => new MediaListSummaryDto
            {
                Id = ml.Id,
                Name = ml.Name,
                Description = ml.Description,
                Icon = ml.Icon,
                IsSystem = ml.IsSystem,
                MoviesCount = ml.Movies.Count,
                ShowsCount = ml.Shows.Count,
                CreatedAt = ml.CreatedAt,
                UpdatedAt = ml.UpdatedAt
            })
            .FirstOrDefaultAsync();

        if (mediaList == null)
            return NotFound();

        return mediaList;
    }

    [HttpGet("{id}/movies")]
    public async Task<ActionResult<PaginatedResult<Movie>>> GetMovies(int id, [FromQuery] int page = 1)
    {
        bool exists = await _context.MediaLists.AnyAsync(ml => ml.Id == id);
        if (!exists)
            return NotFound("List not found");

        int totalCount = await _context.MediaLists
            .Where(ml => ml.Id == id)
            .SelectMany(ml => ml.Movies)
            .CountAsync();

        List<Movie> movies = await _context.MediaLists
            .Where(ml => ml.Id == id)
            .SelectMany(ml => ml.Movies)
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<Movie>
        {
            Items = movies,
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpGet("{id}/shows")]
    public async Task<ActionResult<PaginatedResult<Show>>> GetShows(int id, [FromQuery] int page = 1)
    {
        bool exists = await _context.MediaLists.AnyAsync(ml => ml.Id == id);
        if (!exists)
            return NotFound("List not found");

        int totalCount = await _context.MediaLists
            .Where(ml => ml.Id == id)
            .SelectMany(ml => ml.Shows)
            .CountAsync();

        List<Show> shows = await _context.MediaLists
            .Where(ml => ml.Id == id)
            .SelectMany(ml => ml.Shows)
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<Show>
        {
            Items = shows,
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpPost]
    public async Task<ActionResult<MediaList>> Create(MediaListCreateDto dto)
    {
        MediaList mediaList = new MediaList
        {
            Name = dto.Name,
            Description = dto.Description,
            Icon = dto.Icon
        };

        _context.MediaLists.Add(mediaList);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = mediaList.Id }, mediaList);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, MediaListUpdateDto dto)
    {
        MediaList? mediaList = await _context.MediaLists.FindAsync(id);

        if (mediaList == null)
            return NotFound();

        if (mediaList.IsSystem)
            return BadRequest("Cannot modify system list");

        mediaList.Name = dto.Name ?? mediaList.Name;
        mediaList.Description = dto.Description ?? mediaList.Description;
        mediaList.Icon = dto.Icon ?? mediaList.Icon;
        mediaList.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        MediaList? mediaList = await _context.MediaLists.FindAsync(id);

        if (mediaList == null)
            return NotFound();

        if (mediaList.IsSystem)
            return BadRequest("Cannot delete system list");

        _context.MediaLists.Remove(mediaList);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpPost("{id}/movies/{movieId}")]
    public async Task<IActionResult> AddMovie(int id, int movieId)
    {
        MediaList? mediaList = await _context.MediaLists
            .Include(ml => ml.Movies)
            .FirstOrDefaultAsync(ml => ml.Id == id);

        if (mediaList == null)
            return NotFound("List not found");

        Movie? movie = await _context.Movies.FindAsync(movieId);
        if (movie == null)
            return NotFound("Movie not found");

        if (mediaList.Movies.Any(m => m.Id == movieId))
            return BadRequest("Movie already in list");

        mediaList.Movies.Add(movie);
        mediaList.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id}/movies/{movieId}")]
    public async Task<IActionResult> RemoveMovie(int id, int movieId)
    {
        MediaList? mediaList = await _context.MediaLists
            .Include(ml => ml.Movies)
            .FirstOrDefaultAsync(ml => ml.Id == id);

        if (mediaList == null)
            return NotFound("List not found");

        Movie? movie = mediaList.Movies.FirstOrDefault(m => m.Id == movieId);
        if (movie == null)
            return NotFound("Movie not in list");

        mediaList.Movies.Remove(movie);
        mediaList.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpPost("{id}/shows/{showId}")]
    public async Task<IActionResult> AddShow(int id, int showId)
    {
        MediaList? mediaList = await _context.MediaLists
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.Id == id);

        if (mediaList == null)
            return NotFound("List not found");

        Show? show = await _context.Shows.FindAsync(showId);
        if (show == null)
            return NotFound("Show not found");

        if (mediaList.Shows.Any(s => s.Id == showId))
            return BadRequest("Show already in list");

        mediaList.Shows.Add(show);
        mediaList.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id}/shows/{showId}")]
    public async Task<IActionResult> RemoveShow(int id, int showId)
    {
        MediaList? mediaList = await _context.MediaLists
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.Id == id);

        if (mediaList == null)
            return NotFound("List not found");

        Show? show = mediaList.Shows.FirstOrDefault(s => s.Id == showId);
        if (show == null)
            return NotFound("Show not in list");

        mediaList.Shows.Remove(show);
        mediaList.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
