using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Services;

public class MediaListService(ApiDbContext context)
{
    public const int PageSize = 20;

    public async Task<PaginatedResult<MediaListItemDto>> GetListItemsPaginated(int listId, int page, string type)
    {
        IQueryable<MediaListItem> query = context.MediaListItems
            .Where(i => i.MediaListId == listId);

        query = type.ToLower() switch
        {
            "movie" => query.Where(i => i.MediaType == MediaType.Movie),
            "show" or "tv" => query.Where(i => i.MediaType == MediaType.Show),
            _ => query
        };

        int total = await query.CountAsync();

        List<MediaListItem> items = await query
            .OrderByDescending(i => i.AddedAt)
            .Skip((page - 1) * PageSize).Take(PageSize)
            .ToListAsync();

        List<int> tmdbIds = items.Select(i => i.TmdbId).ToList();
        List<UserMedia> userMediaList = await context.UserMedia
            .Where(m => tmdbIds.Contains(m.TmdbId))
            .ToListAsync();

        List<MediaListItemDto> dtos = items
            .Select(item => new MediaListItemDto(item, userMediaList.FirstOrDefault(m => m.TmdbId == item.TmdbId && m.MediaType == item.MediaType)))
            .ToList();

        return Paginate(dtos, page, total);
    }

    public async Task<int> GetItemsCount(MediaList ml)
    {
        if (!ml.IsSystem)
            return ml.Items.Count;

        return ml.Name switch
        {
            "Seen" => await context.UserMedia.CountAsync(m => m.Seen),
            "J'aime" => await context.UserMedia.CountAsync(m => m.Liked),
            _ => ml.Items.Count
        };
    }

    public static IQueryable<UserMedia> ApplyTypeFilter(IQueryable<UserMedia> query, string type) =>
        type.ToLower() switch
        {
            "movie" => query.Where(m => m.MediaType == MediaType.Movie),
            "show" or "tv" => query.Where(m => m.MediaType == MediaType.Show),
            _ => query
        };

    public static MediaListItemDto ToDto(UserMedia m) => new(m);

    public static PaginatedResult<MediaListItemDto> Paginate(List<MediaListItemDto> items, int page, int total) =>
        new()
        {
            Items = items,
            Page = page,
            PageSize = PageSize,
            TotalCount = total,
            TotalPages = (int)Math.Ceiling(total / (double)PageSize)
        };
}
