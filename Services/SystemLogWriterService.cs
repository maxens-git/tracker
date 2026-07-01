using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;

namespace Tracker.Services;

public class SystemLogWriterService(
    SystemLogQueue queue,
    IServiceScopeFactory scopeFactory) : BackgroundService
{
    private const int BatchSize = 50;
    private static readonly TimeSpan FlushInterval = TimeSpan.FromSeconds(2);
    private static readonly TimeSpan Retention = TimeSpan.FromDays(30);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        List<SystemLogWrite> batch = new(BatchSize);
        DateTime nextCleanup = DateTime.UtcNow.AddMinutes(10);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                SystemLogWrite first = await queue.ReadAsync(stoppingToken);
                batch.Add(first);

                while (batch.Count < BatchSize && queue.TryRead(out SystemLogWrite log))
                {
                    batch.Add(log);
                }

                await Task.Delay(FlushInterval, stoppingToken);

                while (batch.Count < BatchSize && queue.TryRead(out SystemLogWrite log))
                {
                    batch.Add(log);
                }

                await Flush(batch, stoppingToken);

                if (DateTime.UtcNow >= nextCleanup)
                {
                    await Cleanup(stoppingToken);
                    nextCleanup = DateTime.UtcNow.AddHours(6);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch
            {
                await Task.Delay(FlushInterval, stoppingToken);
            }
        }

        if (batch.Count > 0)
            await Flush(batch, CancellationToken.None);
    }

    private async Task Flush(List<SystemLogWrite> batch, CancellationToken cancellationToken)
    {
        if (batch.Count == 0)
            return;

        using IServiceScope scope = scopeFactory.CreateScope();
        ApiDbContext context = scope.ServiceProvider.GetRequiredService<ApiDbContext>();

        context.SystemLogEntries.AddRange(batch.Select(ToEntry));
        await context.SaveChangesAsync(cancellationToken);
        batch.Clear();
    }

    private async Task Cleanup(CancellationToken cancellationToken)
    {
        using IServiceScope scope = scopeFactory.CreateScope();
        ApiDbContext context = scope.ServiceProvider.GetRequiredService<ApiDbContext>();
        DateTime cutoff = DateTime.UtcNow.Subtract(Retention);

        await context.SystemLogEntries
            .Where(log => log.CreatedAt < cutoff)
            .ExecuteDeleteAsync(cancellationToken);
    }

    private static SystemLogEntry ToEntry(SystemLogWrite log) =>
        new()
        {
            CreatedAt = log.CreatedAt,
            Level = log.Level,
            Category = log.Category,
            Message = log.Message,
            Exception = log.Exception,
            EventId = log.EventId,
            TraceId = log.TraceId,
            Method = log.Method,
            Path = log.Path,
            StatusCode = log.StatusCode,
            ElapsedMs = log.ElapsedMs,
        };
}
