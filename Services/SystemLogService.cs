using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Services;

public class SystemLogService(ApiDbContext context)
{
    public const int PageSize = 100;

    public async Task<PaginatedResult<SystemLogDto>> GetRecent(int page, string? level, string? search)
    {
        if (page < 1) page = 1;

        IQueryable<SystemLogEntry> query = context.SystemLogEntries.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(level) &&
            !level.Equals("all", StringComparison.OrdinalIgnoreCase) &&
            Enum.TryParse(level, true, out LogLevel parsedLevel))
        {
            query = query.Where(log => log.Level == parsedLevel);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            string term = search.Trim();
            query = query.Where(log =>
                log.Message.Contains(term) ||
                log.Category.Contains(term) ||
                (log.Path != null && log.Path.Contains(term)) ||
                (log.Exception != null && log.Exception.Contains(term)));
        }

        int total = await query.CountAsync();

        List<SystemLogEntry> logs = await query
            .OrderByDescending(log => log.CreatedAt)
            .ThenByDescending(log => log.Id)
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<SystemLogDto>
        {
            Items = logs.Select(log => new SystemLogDto(log)).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = total,
            TotalPages = (int)Math.Ceiling(total / (double)PageSize),
        };
    }

    public Task Clear() => context.SystemLogEntries.ExecuteDeleteAsync();
}
