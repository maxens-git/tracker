using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Tracker.Controllers;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Tests;

public class IntegrationRegressionTests
{
    [Fact]
    public async Task MultipleShowtimesRejectInvalidDateBeforeCallingAllocine()
    {
        int calls = 0;
        using var http = new HttpClient(new StubHttpHandler((_, _) =>
        {
            calls++;
            throw new InvalidOperationException("No HTTP request expected.");
        }));
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var service = new AllocineService(http, cache, NullLogger<AllocineService>.Instance);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.GetMultipleShowtimes(["P0057"], "2026-02-30", CancellationToken.None));

        Assert.Equal(0, calls);
    }

    [Fact]
    public async Task MultipleShowtimesPropagateClientCancellation()
    {
        using var cancellation = new CancellationTokenSource();
        using var http = new HttpClient(new StubHttpHandler((_, token) =>
        {
            cancellation.Cancel();
            return Task.FromCanceled<HttpResponseMessage>(token);
        }));
        using var cache = new MemoryCache(new MemoryCacheOptions());
        cache.Set("theater:P0057", new TheaterDto("P0057", null, null, null, null, null));
        var service = new AllocineService(http, cache, NullLogger<AllocineService>.Instance);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            service.GetMultipleShowtimes(["P0057"], "2026-11-13", cancellation.Token));
    }

    [Fact]
    public async Task TorrentSearchPropagatesClientCancellation()
    {
        await using var db = new TestDatabase();
        db.Context.Settings.Add(new AppSettings { ProwlarrUrl = "http://prowlarr", ProwlarrApiKey = "test" });
        await db.Context.SaveChangesAsync();
        using var cancellation = new CancellationTokenSource();
        using var http = new HttpClient(new StubHttpHandler((_, token) =>
        {
            cancellation.Cancel();
            return Task.FromCanceled<HttpResponseMessage>(token);
        }));
        var controller = TorrentController(http, db);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => controller.Indexers(cancellation.Token));
    }

    [Fact]
    public async Task TorrentSearchReturnsBadGatewayForUpstreamTimeout()
    {
        await using var db = new TestDatabase();
        db.Context.Settings.Add(new AppSettings { ProwlarrUrl = "http://prowlarr", ProwlarrApiKey = "test" });
        await db.Context.SaveChangesAsync();
        using var http = new HttpClient(new StubHttpHandler((_, _) =>
            Task.FromException<HttpResponseMessage>(new TaskCanceledException("Upstream timeout."))));

        var result = await TorrentController(http, db).Indexers(CancellationToken.None);

        Assert.Equal(StatusCodes.Status502BadGateway, Assert.IsType<ObjectResult>(result.Result).StatusCode);
    }

    [Fact]
    public async Task BookmarksDeduplicateEncodedInfoHashAndIgnoreHashInTitle()
    {
        await using var db = new TestDatabase();
        var controller = new TorrentBookmarksController(db.Context);
        string hash = new('a', 40);

        await controller.Create(Bookmark($"magnet:?dn=urn:btih:wrong&xt=urn:btih:{hash}"));
        var duplicate = await controller.Create(Bookmark($"magnet:?xt=urn%3Abtih%3A{hash.ToUpperInvariant()}&dn=another"));

        var existing = Assert.IsType<TorrentBookmarkDto>(Assert.IsType<OkObjectResult>(duplicate.Result).Value);
        Assert.Equal(hash, (await db.Context.TorrentBookmarks.SingleAsync()).InfoHash);
        Assert.Equal(1, existing.Id);
    }

    [Theory]
    [InlineData("magnet:?xt=urn:btih:")]
    [InlineData("magnet:?dn=no-infohash")]
    [InlineData("magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")]
    public async Task BookmarkFallbackKeysFitDatabaseColumn(string magnet)
    {
        await using var db = new TestDatabase();
        var controller = new TorrentBookmarksController(db.Context);

        var result = await controller.Create(Bookmark(magnet));

        Assert.IsType<CreatedAtActionResult>(result.Result);
        Assert.Equal(40, (await db.Context.TorrentBookmarks.SingleAsync()).InfoHash.Length);
    }

    [Fact]
    public async Task BookmarksRejectNonMagnetLinks()
    {
        await using var db = new TestDatabase();

        var result = await new TorrentBookmarksController(db.Context).Create(Bookmark("https://example.com/file"));

        Assert.IsType<BadRequestObjectResult>(result.Result);
        Assert.Empty(await db.Context.TorrentBookmarks.ToListAsync());
    }

    [Theory]
    [InlineData("ftp://ntfy.example.com")]
    [InlineData("not-a-url")]
    [InlineData("https://ntfy.example.com?token=invalid-base")]
    [InlineData("https://ntfy.example.com#fragment")]
    public async Task SettingsRejectInvalidServiceUrlsBeforeSaving(string url)
    {
        await using var db = new TestDatabase();
        using var http = new HttpClient();

        var result = await SettingsController(http, db).Update(Settings() with { NtfyUrl = url });

        Assert.IsType<BadRequestObjectResult>(result.Result);
        Assert.Empty(await db.Context.Settings.ToListAsync());
    }

    [Fact]
    public async Task SettingsAcceptLocalServiceUrlsAndBlankFallbacks()
    {
        await using var db = new TestDatabase();
        using var http = new HttpClient();

        var result = await SettingsController(http, db).Update(Settings() with
        {
            NtfyUrl = " http://ntfy:80/prefix/ ", ProwlarrUrl = " ", TmdbBaseUrl = null
        });

        Assert.Null(result.Result);
        Assert.Equal("http://ntfy:80/prefix/", result.Value!.NtfyUrl);
        Assert.Null(result.Value.ProwlarrUrl);
    }

    [Fact]
    public void IosNotificationMigrationGuardsTheColumnBeforeRecordingItsHistory()
    {
        var options = new DbContextOptionsBuilder<ApiDbContext>()
            .UseMySql("Server=localhost;Database=tracker", new MySqlServerVersion(new Version(8, 0, 36)))
            .Options;
        using var context = new ApiDbContext(options);

        var script = context.GetService<IMigrator>().GenerateScript(
            "20260927205003_AddWatchHistory", "20261114000000_AddIosNotificationPreference");

        Assert.Contains("FROM INFORMATION_SCHEMA.COLUMNS", script);
        Assert.Contains("TABLE_SCHEMA = DATABASE()", script);
        Assert.Contains("TABLE_NAME = 'Settings'", script);
        Assert.Contains("COLUMN_NAME = 'IosLocalNotificationsEnabled'", script);
        Assert.Contains("'SELECT 1',", script);
        Assert.Contains("'ALTER TABLE `Settings` ADD `IosLocalNotificationsEnabled` tinyint(1) NULL'", script);
        var execution = script.IndexOf("EXECUTE tracker_ios_notification_stmt;", StringComparison.Ordinal);
        var history = script.IndexOf("INSERT INTO `__EFMigrationsHistory`", StringComparison.Ordinal);
        Assert.True(execution >= 0 && history > execution);
    }

    [Fact]
    public async Task WebSettingsUpdatePreservesTheLastIosNotificationChoice()
    {
        await using var db = new TestDatabase();
        using var http = new HttpClient();
        var controller = SettingsController(http, db);

        Assert.Null((await controller.Get()).Value!.IosLocalNotificationsEnabled);

        await controller.Update(Settings() with { IosLocalNotificationsEnabled = true });
        var webSettings = (await controller.Update(Settings() with { NtfyEnabled = true })).Value!;
        Assert.Equal(true, webSettings.IosLocalNotificationsEnabled);
        Assert.True(webSettings.NtfyEnabled);

        await controller.Update(Settings() with { IosLocalNotificationsEnabled = false });
        Assert.Equal(false, (await controller.Get()).Value!.IosLocalNotificationsEnabled);
    }

    [Fact]
    public async Task NtfyTestReturnsBadGatewayForUpstreamFailure()
    {
        await using var db = new TestDatabase();
        db.Context.Settings.Add(new AppSettings { NtfyEnabled = true, NtfyUrl = "http://ntfy", NtfyTopic = "test" });
        await db.Context.SaveChangesAsync();
        using var http = new HttpClient(new StubHttpHandler((_, _) =>
            Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable))));

        var result = await SettingsController(http, db).SendTestNotification(CancellationToken.None);

        Assert.Equal(StatusCodes.Status502BadGateway, Assert.IsType<ObjectResult>(result).StatusCode);
    }

    [Fact]
    public void ApiValidationRejectsStringsLongerThanDatabaseColumns()
    {
        Assert.False(ValidateModel(Bookmark("magnet:?xt=urn:btih:abc") with { Title = new string('a', 1001) }).IsValid);
        Assert.False(ValidateModel(Settings() with { TmdbLanguage = new string('a', 21) }).IsValid);
        Assert.True(ValidateModel(Bookmark("magnet:?xt=urn:btih:abc")).IsValid);
        Assert.True(ValidateModel(Settings()).IsValid);
    }

    private static ModelStateDictionary ValidateModel(object model)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddControllers();
        using var provider = services.BuildServiceProvider();
        var context = new ActionContext(new DefaultHttpContext { RequestServices = provider },
            new RouteData(), new ActionDescriptor(), new ModelStateDictionary());
        provider.GetRequiredService<IObjectModelValidator>().Validate(context, null, string.Empty, model);
        return context.ModelState;
    }

    private static TorrentBookmarkCreateDto Bookmark(string magnet) =>
        new("Title", 1, 1, 0, "Indexer", magnet, null, null);

    private static UpdateSettingsDto Settings() =>
        new(false, null, null, null, 1, 9, 0, null, null, null, null, null, null, null);

    private static SettingsController SettingsController(HttpClient http, TestDatabase db) =>
        new(db.Context, new NtfyService(http, NullLogger<NtfyService>.Instance), NullLogger<SettingsController>.Instance);

    private static TorrentSearchController TorrentController(HttpClient http, TestDatabase db) =>
        new(new ProwlarrService(http, db.Context, NullLogger<ProwlarrService>.Instance),
            new AllDebridService(http, db.Context, NullLogger<AllDebridService>.Instance),
            NullLogger<TorrentSearchController>.Instance);

    private sealed class StubHttpHandler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            send(request, cancellationToken);
    }
}
