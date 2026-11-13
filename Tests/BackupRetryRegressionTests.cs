using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging.Abstractions;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Tests;

public class BackupRetryRegressionTests
{
    [Fact]
    public async Task TransientInsertFailureRollsBackBeforeRetryingWholeRestore()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var failure = new FailAfterFirstRestoreSave();
        await using var context = new ApiDbContext(new DbContextOptionsBuilder<ApiDbContext>()
            .UseSqlite(connection)
            .AddInterceptors(failure)
            .ReplaceService<IExecutionStrategyFactory, RetryStrategyFactory>()
            .Options);
        await context.Database.EnsureCreatedAsync();
        context.UserMedia.Add(new UserMedia(42, MediaType.Movie));
        context.SystemLogEntries.Add(new SystemLogEntry { Message = "old log" });
        await context.SaveChangesAsync();
        failure.FailNextSave = true;
        var backup = new DatabaseBackup
        {
            UserMedia = [new UserMedia(77, MediaType.Movie) { Id = 100, Seen = true, WatchCount = 1 }],
            UserMediaWatchEvents = [new UserMediaWatchEvent(100, new DateTime(2020, 1, 2)) { Id = 200 }],
            SystemLogEntries = [new SystemLogEntry { Id = 300, Message = "restored log" }],
        };

        await new BackupService(context, NullLogger<BackupService>.Instance).Import(backup, default);

        var strategyFactory = Assert.IsType<RetryStrategyFactory>(context.GetService<IExecutionStrategyFactory>());
        // The first attempt already inserted the replacement rows when it failed.
        // Observing the original row before retry proves those writes were rolled back.
        Assert.Equal([42], strategyFactory.MediaBeforeRetry);
        Assert.Equal(77, (await context.UserMedia.SingleAsync()).TmdbId);
        Assert.Equal(100, (await context.UserMediaWatchEvents.SingleAsync()).UserMediaId);
        Assert.Equal("restored log", (await context.SystemLogEntries.SingleAsync()).Message);
        Assert.Equal(SystemLists.Names.Count, await context.MediaLists.CountAsync(l => l.IsSystem));
    }

    public sealed class RetryStrategyFactory(ExecutionStrategyDependencies dependencies) : IExecutionStrategyFactory
    {
        public List<int> MediaBeforeRetry { get; } = [];

        public IExecutionStrategy Create() => new TransientRetryStrategy(dependencies, this);
    }

    private sealed class TransientRetryStrategy(
        ExecutionStrategyDependencies dependencies,
        RetryStrategyFactory factory) : ExecutionStrategy(dependencies, 1, TimeSpan.Zero)
    {
        protected override bool ShouldRetryOn(Exception exception) =>
            exception is SimulatedTransientException ||
            exception is DbUpdateException { InnerException: SimulatedTransientException };

        protected override void OnRetry()
        {
            using var command = Dependencies.CurrentContext.Context.Database.GetDbConnection().CreateCommand();
            command.CommandText = "SELECT TmdbId FROM UserMedia";
            factory.MediaBeforeRetry.Add(Convert.ToInt32(command.ExecuteScalar()));
            base.OnRetry();
        }
    }

    private sealed class FailAfterFirstRestoreSave : SaveChangesInterceptor
    {
        public bool FailNextSave { get; set; }

        public override ValueTask<int> SavedChangesAsync(
            SaveChangesCompletedEventData eventData, int result, CancellationToken cancellationToken = default)
        {
            if (FailNextSave)
            {
                FailNextSave = false;
                throw new DbUpdateException("Transient failure after insert", new SimulatedTransientException());
            }
            return ValueTask.FromResult(result);
        }
    }

    private sealed class SimulatedTransientException : Exception;
}
