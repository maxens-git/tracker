using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Tracker.Controllers;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Tests;

public class MediaRegressionTests
{
    [Theory]
    [InlineData(false, false)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(true, true)]
    public async Task ConcurrentWatchChangesRejectStaleWritesWithoutCorruptingHistory(bool episode, bool remove)
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<ApiDbContext>().UseSqlite(connection).Options;
        await using var seed = new ApiDbContext(options);
        await seed.Database.EnsureCreatedAsync();
        var seedHistory = new WatchHistoryService(seed);
        if (episode)
        {
            var item = new UserEpisode(42, 1, 1, seen: false);
            seed.UserEpisodes.Add(item);
            seedHistory.AddEpisodeWatch(item, DateTime.UtcNow.AddDays(-2));
            seedHistory.AddEpisodeWatch(item, DateTime.UtcNow.AddDays(-1));
        }
        else
        {
            var item = new UserMedia(42, MediaType.Movie);
            seed.UserMedia.Add(item);
            seedHistory.AddMovieWatch(item, DateTime.UtcNow.AddDays(-2));
            seedHistory.AddMovieWatch(item, DateTime.UtcNow.AddDays(-1));
        }
        await seed.SaveChangesAsync();

        await using var first = new ApiDbContext(options);
        await using var second = new ApiDbContext(options);
        var firstHistory = new WatchHistoryService(first);
        var secondHistory = new WatchHistoryService(second);
        if (episode)
        {
            var firstEpisode = await first.UserEpisodes.SingleAsync();
            var secondEpisode = await second.UserEpisodes.SingleAsync();
            if (remove)
            {
                var ids = await seed.UserEpisodeWatchEvents.OrderBy(w => w.Id).Select(w => w.Id).ToListAsync();
                Assert.True(await firstHistory.RemoveEpisodeWatch(firstEpisode, ids[0]));
                Assert.True(await secondHistory.RemoveEpisodeWatch(secondEpisode, ids[1]));
            }
            else
            {
                firstHistory.AddEpisodeWatch(firstEpisode, DateTime.UtcNow);
                secondHistory.AddEpisodeWatch(secondEpisode, DateTime.UtcNow);
            }
        }
        else
        {
            var firstMedia = await first.UserMedia.SingleAsync();
            var secondMedia = await second.UserMedia.SingleAsync();
            if (remove)
            {
                var ids = await seed.UserMediaWatchEvents.OrderBy(w => w.Id).Select(w => w.Id).ToListAsync();
                Assert.True(await firstHistory.RemoveMovieWatch(firstMedia, ids[0]));
                Assert.True(await secondHistory.RemoveMovieWatch(secondMedia, ids[1]));
            }
            else
            {
                firstHistory.AddMovieWatch(firstMedia, DateTime.UtcNow);
                secondHistory.AddMovieWatch(secondMedia, DateTime.UtcNow);
            }
        }

        await first.SaveChangesAsync();
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => second.SaveChangesAsync());

        await using var verification = new ApiDbContext(options);
        int expectedCount = remove ? 1 : 3;
        if (episode)
        {
            var stored = await verification.UserEpisodes.Include(e => e.WatchEvents).SingleAsync();
            Assert.Equal(expectedCount, stored.WatchCount);
            Assert.Equal(expectedCount, stored.WatchEvents.Count);
            Assert.True(stored.Seen);
        }
        else
        {
            var stored = await verification.UserMedia.Include(m => m.WatchEvents).SingleAsync();
            Assert.Equal(expectedCount, stored.WatchCount);
            Assert.Equal(expectedCount, stored.WatchEvents.Count);
            Assert.True(stored.Seen);
        }
    }

    [Fact]
    public void WatchConcurrencyTokensDoNotRequireAMySqlSchemaMigration()
    {
        using var context = new ApiDbContext(new DbContextOptionsBuilder<ApiDbContext>()
            .UseMySql("Server=localhost;Database=tracker_model_check;User ID=unused;Password=unused;",
                new MySqlServerVersion(new Version(8, 0, 0)))
            .Options);

        Assert.False(context.Database.HasPendingModelChanges());
    }

    [Fact]
    public void ConcurrencyFilterReturnsConflictWithoutSwallowingOtherDatabaseFailures()
    {
        var action = new ActionContext(new DefaultHttpContext(), new RouteData(), new ActionDescriptor());
        var context = new ExceptionContext(action, []) { Exception = new DbUpdateConcurrencyException() };
        var filter = new ConcurrencyExceptionFilter();

        filter.OnException(context);

        Assert.True(context.ExceptionHandled);
        Assert.IsType<ConflictObjectResult>(context.Result);

        var unrelated = new ExceptionContext(action, []) { Exception = new DbUpdateException() };
        filter.OnException(unrelated);
        Assert.False(unrelated.ExceptionHandled);
        Assert.Null(unrelated.Result);
    }

    [Fact]
    public async Task MarkingASeasonDoesNotPersistPartialStateWhenSavingFails()
    {
        await using var db = new TestDatabase(new RejectMultipleEpisodes());

        await Assert.ThrowsAsync<InvalidOperationException>(() => Shows(db.Context).MarkSeasonSeen(
            42, 1, new MarkSeasonSeenDto { Seen = true, EpisodeNumbers = [1, 2] }));

        db.Context.ChangeTracker.Clear();
        Assert.Equal(0, await db.Context.UserMedia.CountAsync());
        Assert.Equal(0, await db.Context.UserEpisodes.CountAsync());
        Assert.Equal(0, await db.Context.UserEpisodeWatchEvents.CountAsync());
        Assert.Equal(0, await db.Context.ActivityEvents.CountAsync());
    }

    [Fact]
    public async Task RepeatedEpisodeNumbersCreateOnlyOneEpisodeAndWatch()
    {
        await using var db = new TestDatabase();
        var controller = Shows(db.Context);
        var dto = new MarkShowSeenDto
        {
            Seen = true,
            Seasons =
            [
                new SeasonEpisodesDto { SeasonNumber = 0, EpisodeNumbers = [1, 1, 2] },
                new SeasonEpisodesDto { SeasonNumber = 0, EpisodeNumbers = [2] }
            ]
        };

        Assert.IsType<OkObjectResult>(await controller.MarkShowSeen(42, dto));
        db.Context.ChangeTracker.Clear();
        Assert.Equal(2, await db.Context.UserEpisodes.CountAsync());
        Assert.Equal(2, await db.Context.UserEpisodeWatchEvents.CountAsync());
        Assert.All(await db.Context.UserEpisodes.ToListAsync(), episode => Assert.Equal(1, episode.WatchCount));
        Assert.Equal(1, await db.Context.UserMediaWatchEvents.CountAsync());
    }

    [Fact]
    public async Task InvalidEpisodeBatchIsRejectedBeforeAnyMediaIsCreated()
    {
        await using var db = new TestDatabase();
        Assert.IsType<BadRequestObjectResult>(await Shows(db.Context).MarkSeasonSeen(
            42, 1, new MarkSeasonSeenDto { Seen = true, EpisodeNumbers = [1, -1] }));
        Assert.Empty(db.Context.ChangeTracker.Entries());
        Assert.Equal(0, await db.Context.UserMedia.CountAsync());
    }

    [Fact]
    public async Task NewlyCreatedMovieAndWatchAreSavedTogether()
    {
        await using var db = new TestDatabase();
        var service = new UserMediaService(db.Context);
        var history = new WatchHistoryService(db.Context);
        var movie = await service.EnsureUserMedia(42, MediaType.Movie);
        Assert.Equal(0, await db.Context.UserMedia.CountAsync());
        Assert.Same(movie, await service.EnsureUserMedia(42, MediaType.Movie));

        history.AddMovieWatch(movie, DateTime.UtcNow);
        await db.Context.SaveChangesAsync();
        db.Context.ChangeTracker.Clear();

        var stored = await db.Context.UserMedia.Include(m => m.WatchEvents).SingleAsync();
        Assert.True(stored.Seen);
        Assert.Equal(1, stored.WatchCount);
        Assert.Equal(stored.Id, Assert.Single(stored.WatchEvents).UserMediaId);
    }

    [Fact]
    public async Task ClearingWatchesAlsoRemovesAnUnsavedWatch()
    {
        await using var db = new TestDatabase();
        var movie = await new UserMediaService(db.Context).EnsureUserMedia(42, MediaType.Movie);
        var history = new WatchHistoryService(db.Context);
        history.AddMovieWatch(movie, DateTime.UtcNow);
        await history.ClearMovieWatches(movie);
        await db.Context.SaveChangesAsync();

        Assert.False(movie.Seen);
        Assert.Equal(0, movie.WatchCount);
        Assert.Equal(0, await db.Context.UserMediaWatchEvents.CountAsync());
    }

    [Theory]
    [InlineData(0, 1, 1)]
    [InlineData(int.MinValue, 1, 1)]
    [InlineData(int.MaxValue, int.MaxValue, 0)]
    public async Task ListPaginationHandlesNegativeAndOverflowingPages(int page, int expectedPage, int expectedItems)
    {
        await using var db = new TestDatabase();
        var list = new MediaList("Test");
        db.Context.MediaLists.Add(list);
        db.Context.MediaListItems.Add(new MediaListItem(0, 42, MediaType.Movie) { MediaList = list });
        db.Context.UserMedia.Add(new UserMedia(42, MediaType.Movie) { Liked = true });
        await db.Context.SaveChangesAsync();

        var customPage = await new MediaListService(db.Context).GetListItemsPaginated(list.Id, page, "all");
        var likedPage = await Lists(db.Context).GetLikedItems(page);
        foreach (var result in new[] { customPage, likedPage })
        {
            Assert.Equal(expectedPage, result.Page);
            Assert.Equal(expectedItems, result.Items.Count);
            Assert.Equal(1, result.TotalCount);
        }
    }

    [Fact]
    public async Task SystemListByIdReadsUserStateAndRejectsPhysicalItems()
    {
        await using var db = new TestDatabase();
        var list = new MediaList(SystemLists.Liked, isSystem: true);
        db.Context.MediaLists.Add(list);
        db.Context.UserMedia.Add(new UserMedia(42, MediaType.Movie, title: "Test") { Liked = true });
        await db.Context.SaveChangesAsync();
        var controller = Lists(db.Context);

        var result = await controller.GetItems(list.Id);
        Assert.Equal(42, Assert.Single(result.Value!.Items).TmdbId);
        Assert.IsType<BadRequestObjectResult>(await controller.AddItem(list.Id, new AddListItemDto { TmdbId = 43 }));
        Assert.Equal(0, await db.Context.MediaListItems.CountAsync());
        Assert.Equal(1, await db.Context.UserMedia.CountAsync());
    }

    [Fact]
    public async Task RenamingListToWhitespaceIsRejected()
    {
        await using var db = new TestDatabase();
        var list = new MediaList("Existing");
        db.Context.MediaLists.Add(list);
        await db.Context.SaveChangesAsync();

        Assert.IsType<BadRequestObjectResult>(await Lists(db.Context).Update(list.Id, new MediaListUpdateDto { Name = "   " }));
        db.Context.ChangeTracker.Clear();
        Assert.Equal("Existing", (await db.Context.MediaLists.SingleAsync()).Name);
    }

    [Fact]
    public async Task AddingListItemKeepsItsTitleInUserMediaAndUsesExistingTitleWhenOmitted()
    {
        await using var db = new TestDatabase();
        var first = new MediaList("First");
        var second = new MediaList("Second");
        db.Context.MediaLists.AddRange(first, second);
        await db.Context.SaveChangesAsync();
        var controller = Lists(db.Context);

        await controller.AddItem(first.Id, new AddListItemDto { TmdbId = 42, Title = "Movie title" });
        await controller.AddItem(second.Id, new AddListItemDto { TmdbId = 42 });
        Assert.Equal("Movie title", (await db.Context.UserMedia.SingleAsync()).Title);
        var result = await controller.GetItems(second.Id);
        Assert.Equal("Movie title", Assert.Single(result.Value!.Items).Title);
    }

    [Fact]
    public async Task RepeatedLikeDoesNotDuplicateActivity()
    {
        await using var db = new TestDatabase();
        var controller = new MediaController(db.Context, new UserMediaService(db.Context),
            new ActivityService(db.Context), new WatchHistoryService(db.Context));

        await controller.MarkLiked(42, "movie", null, null, true);
        await controller.MarkLiked(42, "movie", null, null, true);

        Assert.Equal(1, await db.Context.ActivityEvents.CountAsync());
    }

    [Fact]
    public void MediaDtosRejectInvalidIdentifiersTypesLengthsAndDatabaseDates()
    {
        Assert.False(IsValid(new AddListItemDto { TmdbId = 0 }));
        Assert.False(IsValid(new AddListItemDto { TmdbId = 42, MediaType = "moive" }));
        Assert.False(IsValid(new AddWatchDto { WatchedAt = DateTime.MinValue }));
        Assert.False(IsValid(new MediaListCreateDto { Name = new string('a', 101) }));
        Assert.True(IsValid(new AddListItemDto { TmdbId = 42, MediaType = "TV" }));
        Assert.True(IsValid(new AddWatchDto { WatchedAt = DateTime.UtcNow }));
    }

    private static bool IsValid(object value) => Validator.TryValidateObject(
        value, new ValidationContext(value), new List<ValidationResult>(), validateAllProperties: true);

    private static ShowEpisodesController Shows(ApiDbContext context) => new(
        context, new UserMediaService(context), new ActivityService(context), new WatchHistoryService(context));

    private static MediaListsController Lists(ApiDbContext context) => new(
        context, new MediaListService(context), new UserMediaService(context), new ActivityService(context));

    private sealed class RejectMultipleEpisodes : SaveChangesInterceptor
    {
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
        {
            if (eventData.Context!.ChangeTracker.Entries<UserEpisode>().Count() >= 2)
                throw new InvalidOperationException("Simulated save failure");
            return base.SavingChangesAsync(eventData, result, cancellationToken);
        }
    }
}
