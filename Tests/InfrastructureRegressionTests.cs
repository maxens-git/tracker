using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tracker.Data;
using Tracker.Models;
using Tracker.Services;

namespace Tracker.Tests;

public class InfrastructureRegressionTests
{
    [Fact]
    public async Task PaginationPastIntegerRangeReturnsEmptyPage()
    {
        await using var db = new TestDatabase();
        db.Context.ActivityEvents.Add(new ActivityEvent(ActivityType.MarkedSeen, 1, MediaType.Movie));
        db.Context.SystemLogEntries.Add(new SystemLogEntry { Message = "hello" });
        await db.Context.SaveChangesAsync();

        var activity = await new ActivityService(db.Context).GetRecent(int.MaxValue);
        var logs = await new SystemLogService(db.Context).GetRecent(int.MaxValue, null, null);

        Assert.Empty(activity.Items);
        Assert.Empty(logs.Items);
        Assert.Equal(1, activity.TotalCount);
        Assert.Equal(1, logs.TotalCount);
    }

    [Fact]
    public async Task NullGenresDoNotBreakStats()
    {
        await using var db = new TestDatabase();
        db.Context.UserMedia.Add(new UserMedia(1, MediaType.Movie, genreNamesJson: "[null,\" Drame \",\"drame\",\"\"]") { Seen = true });
        await db.Context.SaveChangesAsync();

        var stats = await new StatsService(db.Context).GetStats();

        var genre = Assert.Single(stats.FavoriteGenres);
        Assert.Equal("Drame", genre.Name);
        Assert.Equal(1, genre.Count);
    }

    [Fact]
    public async Task FailedRequestsLogServerErrorAndBoundedFields()
    {
        var queue = new SystemLogQueue();
        var context = new DefaultHttpContext { TraceIdentifier = new string('t', 200) };
        context.Request.Method = new string('M', 30);
        context.Request.Path = "/api/" + new string('p', 1200);
        var middleware = new RequestLogMiddleware(_ => throw new InvalidOperationException("broken"), queue);

        await Assert.ThrowsAsync<InvalidOperationException>(() => middleware.Invoke(context));

        Assert.True(queue.TryRead(out var log));
        Assert.Equal(500, log.StatusCode);
        Assert.Equal(1000, log.Path!.Length);
        Assert.Equal(100, log.TraceId!.Length);
        Assert.Equal(12, log.Method!.Length);
    }

    [Fact]
    public async Task ClientCancellationDoesNotLogAServerFailure()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var context = new DefaultHttpContext { RequestAborted = cancellation.Token };
        context.Request.Path = "/api/media/states";
        var queue = new SystemLogQueue();
        var middleware = new RequestLogMiddleware(_ => throw new OperationCanceledException(cancellation.Token), queue);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => middleware.Invoke(context));

        Assert.True(queue.TryRead(out var log));
        Assert.Equal(499, log.StatusCode);
        Assert.Equal(LogLevel.Information, log.Level);
        Assert.False(queue.TryRead(out _));
    }

    [Fact]
    public async Task LogWriterRetriesFailedBatchWithoutWaitingForAnotherLog()
    {
        await using var db = new TestDatabase();
        var interceptor = new FailFirstLogSave();
        var services = new ServiceCollection();
        services.AddScoped(_ => new ApiDbContext(new DbContextOptionsBuilder<ApiDbContext>()
            .UseSqlite(db.Context.Database.GetDbConnection())
            .AddInterceptors(interceptor)
            .Options));
        await using var provider = services.BuildServiceProvider();
        var queue = new SystemLogQueue();
        queue.TryWrite(new SystemLogWrite(DateTime.UtcNow, LogLevel.Information, "test", "retry me", null, 0, null, null, null, null, null));
        using var writer = new SystemLogWriterService(queue, provider.GetRequiredService<IServiceScopeFactory>());
        await writer.StartAsync(default);
        try
        {
            await interceptor.Saved.Task.WaitAsync(TimeSpan.FromSeconds(15));
        }
        finally
        {
            await writer.StopAsync(default);
        }

        Assert.Equal("retry me", (await db.Context.SystemLogEntries.SingleAsync()).Message);
        Assert.Equal(2, interceptor.Attempts);
    }

    [Fact]
    public async Task JustWatchSeedPopulatesWatchHistoryAndCounters()
    {
        await using var db = new TestDatabase();
        string directory = Path.Combine(Path.GetTempPath(), $"tracker-seed-{Guid.NewGuid():N}");
        Directory.CreateDirectory(Path.Combine(directory, "Seed", "Data"));
        try
        {
            await File.WriteAllTextAsync(Path.Combine(directory, "Seed", "Data", "justwatch_seenlist.json"), """
                [
                  {"type":"MOVIE","tmdbId":"10","createdAt":"2020-01-02T00:00:00Z"},
                  {"type":"SHOW","tmdbId":"20","createdAt":"2020-01-03T00:00:00Z",
                   "seasons":[{"seasonNumber":1,"episodeCount":1,
                     "episodes":[{"episodeNumber":1,"seen":true,"seenAt":"2020-01-04T00:00:00Z"}]}]}
                ]
                """);
            await DbSeeder.SeedSystemListsAsync(db.Context);
            await DbSeeder.SeedFromJustWatchAsync(db.Context, directory);
            db.Context.ChangeTracker.Clear();

            Assert.All(await db.Context.UserMedia.ToListAsync(), m => Assert.Equal(1, m.WatchCount));
            Assert.Equal(2, await db.Context.UserMediaWatchEvents.CountAsync());
            Assert.Equal(1, (await db.Context.UserEpisodes.SingleAsync()).WatchCount);
            Assert.Equal(new DateTime(2020, 1, 4), (await db.Context.UserEpisodeWatchEvents.SingleAsync()).WatchedAt);

            await DbSeeder.SeedFromJustWatchAsync(db.Context, directory);
            Assert.Equal(2, await db.Context.UserMediaWatchEvents.CountAsync());
        }
        finally
        {
            Directory.Delete(directory, recursive: true);
        }
    }

    private sealed class FailFirstLogSave : SaveChangesInterceptor
    {
        public int Attempts { get; private set; }
        public TaskCompletionSource Saved { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            if (++Attempts == 1)
                throw new InvalidOperationException("Database temporarily unavailable");
            return ValueTask.FromResult(result);
        }

        public override ValueTask<int> SavedChangesAsync(
            SaveChangesCompletedEventData eventData, int result, CancellationToken cancellationToken = default)
        {
            Saved.TrySetResult();
            return ValueTask.FromResult(result);
        }
    }
}
