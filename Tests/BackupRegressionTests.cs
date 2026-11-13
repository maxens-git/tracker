using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging.Abstractions;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Tests;

public class BackupRegressionTests
{
    [Theory]
    [InlineData("{}")]
    [InlineData("{\"format\":\"tracker-backup\",\"version\":1}")]
    [InlineData("null")]
    [InlineData("{not json}")]
    public async Task InvalidDocumentCannotReplaceExistingData(string json)
    {
        await using var db = new TestDatabase();
        db.Context.UserMedia.Add(new UserMedia(42, MediaType.Movie));
        await db.Context.SaveChangesAsync();
        var service = CreateService(db);
        await using var stream = new MemoryStream(Encoding.UTF8.GetBytes(json));

        await Assert.ThrowsAsync<BackupValidationException>(async () =>
            await service.Import(await service.Read(stream, default), default));

        Assert.Equal(42, (await db.Context.UserMedia.SingleAsync()).TmdbId);
    }

    [Theory]
    [InlineData("settings")]
    [InlineData("userMedia")]
    [InlineData("userMediaWatchEvents")]
    [InlineData("userEpisodes")]
    [InlineData("userEpisodeWatchEvents")]
    [InlineData("mediaLists")]
    [InlineData("mediaListItems")]
    [InlineData("activityEvents")]
    [InlineData("trackedMediaReleases")]
    [InlineData("releaseNotifications")]
    [InlineData("knownSeasons")]
    [InlineData("torrentBookmarks")]
    [InlineData("favoriteTheaters")]
    public async Task MissingOrNullTableIsRejected(string table)
    {
        await using var db = new TestDatabase();
        var service = CreateService(db);
        JsonObject document = JsonSerializer.SerializeToNode(new DatabaseBackup(), BackupService.JsonOptions)!.AsObject();
        document.Remove(table);
        await using (var missing = new MemoryStream(Encoding.UTF8.GetBytes(document.ToJsonString())))
            await Assert.ThrowsAsync<BackupValidationException>(() => service.Read(missing, default));

        document[table] = null;
        await using var nullTable = new MemoryStream(Encoding.UTF8.GetBytes(document.ToJsonString()));
        DatabaseBackup backup = await service.Read(nullTable, default);
        await Assert.ThrowsAsync<BackupValidationException>(() => service.Import(backup, default));
    }

    [Theory]
    [InlineData("null-row")]
    [InlineData("duplicate-id")]
    [InlineData("zero-id")]
    [InlineData("orphan-watch")]
    [InlineData("invalid-version")]
    public async Task InvalidRowsAreRejectedBeforeDeletingData(string problem)
    {
        await using var db = new TestDatabase();
        db.Context.UserMedia.Add(new UserMedia(42, MediaType.Movie));
        await db.Context.SaveChangesAsync();
        var backup = new DatabaseBackup();
        switch (problem)
        {
            case "null-row": backup.UserMedia.Add(null!); break;
            case "duplicate-id":
                backup.UserMedia.Add(new UserMedia(1, MediaType.Movie) { Id = 7 });
                backup.UserMedia.Add(new UserMedia(2, MediaType.Movie) { Id = 7 });
                break;
            case "zero-id": backup.UserMedia.Add(new UserMedia(1, MediaType.Movie)); break;
            case "orphan-watch": backup.UserMediaWatchEvents.Add(new UserMediaWatchEvent(7, DateTime.UtcNow) { Id = 1 }); break;
            case "invalid-version": backup.Version = 0; break;
        }

        await Assert.ThrowsAsync<BackupValidationException>(() => CreateService(db).Import(backup, default));
        Assert.Equal(42, (await db.Context.UserMedia.SingleAsync()).TmdbId);
    }

    [Fact]
    public async Task RestoreKeepsRelationshipsAndRecreatesSystemLists()
    {
        await using var db = new TestDatabase();
        db.Context.UserMedia.Add(new UserMedia(42, MediaType.Movie));
        db.Context.SystemLogEntries.Add(new SystemLogEntry { Message = "kept" });
        await db.Context.SaveChangesAsync();
        var backup = new DatabaseBackup
        {
            UserMedia = [new UserMedia(12, MediaType.Movie) { Id = 100, Seen = true, WatchCount = 1 }],
            UserMediaWatchEvents = [new UserMediaWatchEvent(100, new DateTime(2020, 1, 2)) { Id = 200 }],
        };
        var service = CreateService(db);
        await using var stream = new MemoryStream(JsonSerializer.SerializeToUtf8Bytes(backup, BackupService.JsonOptions));

        await service.Import(await service.Read(stream, default), default);

        Assert.Equal(12, (await db.Context.UserMedia.SingleAsync()).TmdbId);
        Assert.Equal(100, (await db.Context.UserMediaWatchEvents.SingleAsync()).UserMediaId);
        Assert.Equal(SystemLists.Names.Count, await db.Context.MediaLists.CountAsync(l => l.IsSystem));
        Assert.Equal("kept", (await db.Context.SystemLogEntries.SingleAsync()).Message);
    }

    [Fact]
    public async Task SystemListFailureRollsBackEntireRestore()
    {
        var failure = new RejectSystemLists();
        await using var db = new TestDatabase(failure);
        db.Context.UserMedia.Add(new UserMedia(42, MediaType.Movie));
        await db.Context.SaveChangesAsync();
        failure.Enabled = true;

        await Assert.ThrowsAsync<InvalidOperationException>(() => CreateService(db).Import(new DatabaseBackup(), default));

        db.Context.ChangeTracker.Clear();
        Assert.Equal(42, (await db.Context.UserMedia.SingleAsync()).TmdbId);
    }

    private static BackupService CreateService(TestDatabase db) =>
        new(db.Context, NullLogger<BackupService>.Instance);

    private sealed class RejectSystemLists : SaveChangesInterceptor
    {
        public bool Enabled { get; set; }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            if (Enabled && eventData.Context!.ChangeTracker.Entries<MediaList>().Any(e => e.Entity.IsSystem))
                throw new InvalidOperationException("Simulated system list failure");
            return ValueTask.FromResult(result);
        }
    }
}
