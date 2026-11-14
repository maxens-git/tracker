using Microsoft.EntityFrameworkCore;
using Tracker.Controllers;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Tests;

public class ListSearchRegressionTests
{
    public static TheoryData<string> Routes => new()
    {
        "seen", "liked", "watchlist", "custom", "seen-id", "liked-id", "watchlist-id"
    };

    [Theory]
    [MemberData(nameof(Routes))]
    public async Task SearchFindsOlderItemsBeyondTheFirstPageAndRespectsTypeAndListScope(string route)
    {
        await using var db = new TestDatabase();
        var lists = AddLists(db.Context);
        for (int id = 1; id <= 25; id++)
            AddMedia(db.Context, lists, id, $"Other title {id}");
        AddMedia(db.Context, lists, 100, "The NEEDLE", addedAt: new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc));
        AddMedia(db.Context, lists, 101, "The needle series", MediaType.Show);

        var unrelated = new MediaList("Unrelated");
        db.Context.MediaLists.Add(unrelated);
        db.Context.MediaListItems.Add(new MediaListItem(0, 102, MediaType.Movie, title: "The needle elsewhere")
        {
            MediaList = unrelated
        });
        db.Context.UserMedia.Add(new UserMedia(102, MediaType.Movie, title: "The needle elsewhere"));
        await db.Context.SaveChangesAsync();

        var firstPage = await Read(db.Context, lists, route, type: "movie");
        Assert.DoesNotContain(firstPage.Items, i => i.TmdbId == 100);

        var result = await Read(db.Context, lists, route, type: "movie", search: "  NeEdLe  ");

        Assert.Equal(100, Assert.Single(result.Items).TmdbId);
        Assert.Equal(1, result.TotalCount);
        Assert.Equal(1, result.TotalPages);
        Assert.Equal(1, result.Page);
    }

    [Theory]
    [MemberData(nameof(Routes))]
    public async Task SearchPaginatesOnlyMatchesAndKeepsFilteredTotals(string route)
    {
        await using var db = new TestDatabase();
        var lists = AddLists(db.Context);
        for (int id = 1; id <= 48; id++)
            AddMedia(db.Context, lists, id, id <= 45 ? $"Matching title {id}" : $"Other title {id}");
        await db.Context.SaveChangesAsync();

        var first = await Read(db.Context, lists, route, search: "matching");
        var second = await Read(db.Context, lists, route, page: 2, search: "matching");
        var third = await Read(db.Context, lists, route, page: 3, search: "matching");
        var beyond = await Read(db.Context, lists, route, page: 4, search: "matching");

        Assert.Equal(20, first.Items.Count);
        Assert.Equal(20, second.Items.Count);
        Assert.Equal(5, third.Items.Count);
        Assert.Empty(beyond.Items);
        Assert.Equal(45, first.Items.Concat(second.Items).Concat(third.Items).Select(i => i.TmdbId).Distinct().Count());
        foreach (var result in new[] { first, second, third, beyond })
        {
            Assert.Equal(45, result.TotalCount);
            Assert.Equal(3, result.TotalPages);
            Assert.Equal(20, result.PageSize);
            Assert.All(result.Items, i => Assert.Contains("Matching", i.Title));
        }
        Assert.Equal(2, second.Page);
        Assert.Equal(3, third.Page);
        Assert.Equal(4, beyond.Page);
    }

    [Theory]
    [MemberData(nameof(Routes))]
    public async Task EmptySearchPreservesUnfilteredPaginationIncludingMissingTitles(string route)
    {
        await using var db = new TestDatabase();
        var lists = AddLists(db.Context);
        for (int id = 1; id <= 23; id++)
            AddMedia(db.Context, lists, id, id % 2 == 0 ? "Known title" : null);
        await db.Context.SaveChangesAsync();

        var unfiltered = await Read(db.Context, lists, route, page: 2);
        foreach (string search in new[] { "", " \t\n " })
        {
            var result = await Read(db.Context, lists, route, page: 2, search: search);
            Assert.Equal(unfiltered.Items.Select(i => i.TmdbId), result.Items.Select(i => i.TmdbId));
            Assert.Equal(23, result.TotalCount);
            Assert.Equal(2, result.TotalPages);
            Assert.Equal(3, result.Items.Count);
        }
    }

    [Theory]
    [MemberData(nameof(Routes))]
    public async Task SearchTreatsSqlPatternCharactersAsLiteralText(string route)
    {
        await using var db = new TestDatabase();
        var lists = AddLists(db.Context);
        AddMedia(db.Context, lists, 1, @"100%_real\title");
        AddMedia(db.Context, lists, 2, "A normal title");
        await db.Context.SaveChangesAsync();

        foreach (string search in new[] { "%", "_", "\\", "missing" })
        {
            var result = await Read(db.Context, lists, route, search: search);
            if (search == "missing")
            {
                Assert.Empty(result.Items);
                Assert.Equal(0, result.TotalCount);
                Assert.Equal(0, result.TotalPages);
            }
            else
            {
                Assert.Equal(1, Assert.Single(result.Items).TmdbId);
                Assert.Equal(1, result.TotalCount);
            }
        }
    }

    [Fact]
    public async Task CustomListSearchUsesTheDisplayedFallbackAndMatchesBothMediaIdAndType()
    {
        await using var db = new TestDatabase();
        var lists = AddLists(db.Context);
        for (int id = 1; id <= 6; id++)
            db.Context.MediaListItems.Add(new MediaListItem(0, id, MediaType.Movie,
                title: id == 3 ? "Other title" : id == 4 ? "Needle item title" : null)
            {
                MediaList = lists.Custom
            });
        db.Context.UserMedia.AddRange(
            new UserMedia(1, MediaType.Movie, title: "Needle fallback"),
            new UserMedia(2, MediaType.Show, title: "Needle wrong type"),
            new UserMedia(3, MediaType.Movie, title: "Needle hidden by item title"),
            new UserMedia(4, MediaType.Movie, title: "Other user title"),
            new UserMedia(5, MediaType.Movie),
            new UserMedia(6, MediaType.Movie, title: "Other movie title"),
            new UserMedia(6, MediaType.Show, title: "Needle same id different type"));
        await db.Context.SaveChangesAsync();

        var result = await Read(db.Context, lists, "custom", search: "needle");

        Assert.Equal(new[] { 1, 4 }, result.Items.Select(i => i.TmdbId).Order());
        Assert.Equal("Needle fallback", result.Items.Single(i => i.TmdbId == 1).Title);
        Assert.Equal("Needle item title", result.Items.Single(i => i.TmdbId == 4).Title);
        Assert.Equal(2, result.TotalCount);
    }

    [Fact]
    public async Task SearchKeepsSeenAndLikedMembershipIndependent()
    {
        await using var db = new TestDatabase();
        var lists = AddLists(db.Context);
        db.Context.UserMedia.AddRange(
            new UserMedia(1, MediaType.Movie, title: "Needle seen") { Seen = true },
            new UserMedia(2, MediaType.Movie, title: "Needle liked") { Liked = true },
            new UserMedia(3, MediaType.Movie, title: "Needle neither"));
        await db.Context.SaveChangesAsync();

        foreach (string route in new[] { "seen", "seen-id", "liked", "liked-id" })
        {
            var result = await Read(db.Context, lists, route, search: "needle");
            Assert.Equal(route.StartsWith("seen") ? 1 : 2, Assert.Single(result.Items).TmdbId);
        }
        Assert.Empty((await Read(db.Context, lists, "watchlist", search: "needle")).Items);
    }

    [Fact]
    public void BothSearchQueriesTranslateToMySqlWithoutClientFiltering()
    {
        using var context = new ApiDbContext(new DbContextOptionsBuilder<ApiDbContext>()
            .UseMySql("Server=localhost;Database=tracker_translation_check;User ID=unused;Password=unused;",
                new MySqlServerVersion(new Version(8, 0, 0)))
            .Options);

        string userSql = MediaListService.ApplySearchFilter(context.UserMedia, " Needle%_ ").ToQueryString();
        string listSql = new MediaListService(context)
            .ApplySearchFilter(context.MediaListItems, " Needle%_ ").ToQueryString();

        Assert.Contains("WHERE", userSql);
        Assert.Contains("LOWER(", userSql);
        Assert.Contains("WHERE", listSql);
        Assert.Contains("EXISTS", listSql);
        Assert.Contains("LOWER(", listSql);
    }

    private sealed record Lists(MediaList Seen, MediaList Liked, MediaList Watchlist, MediaList Custom);

    private static Lists AddLists(ApiDbContext context)
    {
        var lists = new Lists(
            new MediaList(SystemLists.Seen, isSystem: true),
            new MediaList(SystemLists.Liked, isSystem: true),
            new MediaList(SystemLists.Watchlist, isSystem: true),
            new MediaList("Custom"));
        context.MediaLists.AddRange(lists.Seen, lists.Liked, lists.Watchlist, lists.Custom);
        return lists;
    }

    private static void AddMedia(ApiDbContext context, Lists lists, int id, string? title,
        MediaType type = MediaType.Movie, DateTime? addedAt = null)
    {
        DateTime date = addedAt ?? new DateTime(2026, 11, 14, 12, 0, 0, DateTimeKind.Utc).AddMinutes(id);
        context.UserMedia.Add(new UserMedia(id, type, title: title) { Seen = true, Liked = true, AddedAt = date });
        foreach (var list in new[] { lists.Watchlist, lists.Custom })
            context.MediaListItems.Add(new MediaListItem(0, id, type, title: title)
            {
                MediaList = list,
                AddedAt = date
            });
    }

    private static async Task<PaginatedResult<MediaListItemDto>> Read(ApiDbContext context, Lists lists, string route,
        int page = 1, string type = "all", string? search = null)
    {
        var controller = new MediaListsController(context, new MediaListService(context),
            new UserMediaService(context), new ActivityService(context));
        return route switch
        {
            "seen" => await controller.GetSeenItems(page, type, search),
            "liked" => await controller.GetLikedItems(page, type, search),
            "watchlist" => (await controller.GetWatchlistItems(page, type, search)).Value!,
            "custom" => (await controller.GetItems(lists.Custom.Id, page, type, search)).Value!,
            "seen-id" => (await controller.GetItems(lists.Seen.Id, page, type, search)).Value!,
            "liked-id" => (await controller.GetItems(lists.Liked.Id, page, type, search)).Value!,
            "watchlist-id" => (await controller.GetItems(lists.Watchlist.Id, page, type, search)).Value!,
            _ => throw new ArgumentOutOfRangeException(nameof(route))
        };
    }
}
