using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Services;

/// <summary>
/// Journalise les actions de l'utilisateur et expose le flux d'activité paginé.
/// <see cref="Log"/> se contente d'ajouter l'événement au contexte : la persistance
/// est assurée par le <c>SaveChangesAsync</c> que l'appelant exécute de toute façon
/// (le DbContext étant partagé — lifetime scoped — au sein d'une même requête).
/// </summary>
public class ActivityService(ApiDbContext context)
{
    public const int PageSize = 30;

    /// <summary>Enregistre une action. N'appelle pas SaveChanges (laissé à l'appelant).</summary>
    public void Log(
        ActivityType type, int tmdbId, MediaType mediaType,
        string? posterPath = null, int? listId = null, string? listName = null)
    {
        context.ActivityEvents.Add(
            new ActivityEvent(type, tmdbId, mediaType, posterPath, listId, listName));
    }

    /// <summary>Flux d'activité, du plus récent au plus ancien, paginé.</summary>
    public async Task<PaginatedResult<ActivityDto>> GetRecent(int page)
    {
        if (page < 1) page = 1;

        int total = await context.ActivityEvents.CountAsync();

        List<ActivityEvent> events = await context.ActivityEvents
            .OrderByDescending(e => e.CreatedAt)
            .ThenByDescending(e => e.Id)
            .Skip((page - 1) * PageSize).Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<ActivityDto>
        {
            Items = events.Select(e => new ActivityDto(e)).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = total,
            TotalPages = (int)Math.Ceiling(total / (double)PageSize),
        };
    }
}
