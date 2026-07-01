using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TrackedMediaController(ApiDbContext context, ILogger<TrackedMediaController> logger) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<TrackedMediaDto>>> GetAll()
    {
        List<TrackedMediaRelease> items = await context.TrackedMediaReleases
            .OrderByDescending(m => m.AddedAt)
            .ToListAsync();

        return items.Select(ToDto).ToList();
    }

    [HttpGet("state")]
    public async Task<ActionResult<TrackedMediaStateDto>> GetState([FromQuery] int tmdbId, [FromQuery] string type = "movie")
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        bool tracked = await context.TrackedMediaReleases.AnyAsync(m => m.TmdbId == tmdbId && m.MediaType == mediaType);
        return new TrackedMediaStateDto(tmdbId, mediaType.ToApiString(), tracked);
    }

    [HttpPost]
    public async Task<ActionResult<TrackedMediaDto>> Add(AddTrackedMediaDto dto)
    {
        MediaType mediaType = MediaTypeExtensions.Parse(dto.MediaType);
        string title = string.IsNullOrWhiteSpace(dto.Title) ? "Sans titre" : dto.Title.Trim();

        TrackedMediaRelease? existing = await context.TrackedMediaReleases
            .FirstOrDefaultAsync(m => m.TmdbId == dto.TmdbId && m.MediaType == mediaType);

        if (existing != null)
        {
            existing.Title = title;
            existing.PosterPath = dto.PosterPath.NullIfBlank();
            await context.SaveChangesAsync();
            logger.LogInformation("Média suivi mis à jour: {Title} ({Type} {TmdbId}).",
                existing.Title, existing.MediaType, existing.TmdbId);
            return ToDto(existing);
        }

        TrackedMediaRelease item = new(dto.TmdbId, mediaType, title, dto.PosterPath.NullIfBlank());
        context.TrackedMediaReleases.Add(item);
        await context.SaveChangesAsync();
        logger.LogInformation("Média ajouté au suivi des sorties: {Title} ({Type} {TmdbId}).",
            item.Title, item.MediaType, item.TmdbId);

        // Pas d'endpoint GET par ressource unique : les clients consomment le corps
        // renvoyé, on évite donc un header Location trompeur et on reste cohérent
        // avec la branche « mise à jour » ci-dessus.
        return ToDto(item);
    }

    [HttpDelete("{tmdbId}")]
    public async Task<IActionResult> Remove(int tmdbId, [FromQuery] string type = "movie")
    {
        MediaType mediaType = MediaTypeExtensions.Parse(type);
        TrackedMediaRelease? item = await context.TrackedMediaReleases
            .FirstOrDefaultAsync(m => m.TmdbId == tmdbId && m.MediaType == mediaType);

        if (item == null) return NotFound();

        context.TrackedMediaReleases.Remove(item);
        await context.SaveChangesAsync();
        logger.LogInformation("Média retiré du suivi des sorties: {Title} ({Type} {TmdbId}).",
            item.Title, item.MediaType, item.TmdbId);
        return NoContent();
    }

    private static TrackedMediaDto ToDto(TrackedMediaRelease item) =>
        new(item.Id, item.TmdbId, item.MediaType.ToApiString(), item.Title, item.PosterPath, item.AddedAt);
}
