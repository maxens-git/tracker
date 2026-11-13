using System.Net;
using System.Reflection;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Tracker.Data;
using Tracker.Models;
using Tracker.Services;

namespace Tracker.Tests;

public class ReleaseRegressionTests
{
    [Fact]
    public async Task TimedOutNotificationIsRetriedInTheSameDayWithoutDuplicatingSuccessfulSends()
    {
        await using var db = new TestDatabase();
        db.Context.Settings.Add(NotificationSettings());
        db.Context.TrackedMediaReleases.Add(new(42, MediaType.Movie, "Film", null));
        await db.Context.SaveChangesAsync();

        int sends = 0;
        using var tmdb = new HttpClient(new StubHandler((_, _) => Json(new
        {
            title = "Film", release_date = Today().ToString("yyyy-MM-dd")
        })));
        using var ntfy = new HttpClient(new StubHandler((_, _) =>
        {
            if (++sends == 1) throw new TaskCanceledException("Simulated HTTP timeout");
            return new HttpResponseMessage(HttpStatusCode.OK);
        }));
        using var provider = WorkerServices(db.Context, tmdb, ntfy);
        var worker = new ReleaseNotificationWorker(provider.GetRequiredService<IServiceScopeFactory>(), NullLogger<ReleaseNotificationWorker>.Instance);

        await Tick(worker);
        Assert.Empty(await db.Context.ReleaseNotifications.ToListAsync());
        await Tick(worker);
        await Tick(worker);

        Assert.Equal(2, sends);
        Assert.Single(await db.Context.ReleaseNotifications.ToListAsync());
    }

    [Fact]
    public async Task FailedSeasonAnnouncementIsNotMarkedKnownUntilItHasBeenSent()
    {
        await using var db = new TestDatabase();
        db.Context.Settings.Add(NotificationSettings());
        db.Context.TrackedMediaReleases.Add(new(42, MediaType.Show, "Série", null));
        db.Context.KnownSeasons.Add(new(42, 1, "Saison 1", "2000-01-01", 10));
        await db.Context.SaveChangesAsync();
        using var tmdb = new HttpClient(new StubHandler((_, _) => Json(new
        {
            name = "Série",
            seasons = new[]
            {
                new { season_number = 1, name = "Saison 1", air_date = (string?)"2000-01-01", episode_count = 10 },
                new { season_number = 2, name = "Saison 2", air_date = (string?)null, episode_count = 10 }
            }
        })));
        int sends = 0;
        using var ntfy = new HttpClient(new StubHandler((_, _) =>
            new HttpResponseMessage(++sends == 1 ? HttpStatusCode.ServiceUnavailable : HttpStatusCode.OK)));
        using var provider = WorkerServices(db.Context, tmdb, ntfy);
        var worker = new ReleaseNotificationWorker(provider.GetRequiredService<IServiceScopeFactory>(), NullLogger<ReleaseNotificationWorker>.Instance);

        await Tick(worker);
        Assert.False(await db.Context.KnownSeasons.AnyAsync(s => s.SeasonNumber == 2));
        await Tick(worker);
        await Tick(worker);

        Assert.True(await db.Context.KnownSeasons.AnyAsync(s => s.SeasonNumber == 2));
        Assert.Equal(2, sends);
    }

    [Fact]
    public async Task TmdbFailureIsRetriedWhileOtherMediaContinueToBeNotified()
    {
        await using var db = new TestDatabase();
        db.Context.Settings.Add(NotificationSettings());
        db.Context.TrackedMediaReleases.AddRange(new(41, MediaType.Movie, "Premier", null), new(42, MediaType.Movie, "Second", null));
        await db.Context.SaveChangesAsync();
        int failingRequests = 0;
        using var tmdb = new HttpClient(new StubHandler((request, _) =>
        {
            if (request.RequestUri!.AbsolutePath.EndsWith("/41") && ++failingRequests == 1)
                return new HttpResponseMessage(HttpStatusCode.ServiceUnavailable);
            return Json(new { title = "Film", release_date = Today().ToString("yyyy-MM-dd") });
        }));
        int sends = 0;
        using var ntfy = new HttpClient(new StubHandler((_, _) =>
        {
            sends++;
            return new HttpResponseMessage(HttpStatusCode.OK);
        }));
        using var provider = WorkerServices(db.Context, tmdb, ntfy);
        var worker = new ReleaseNotificationWorker(provider.GetRequiredService<IServiceScopeFactory>(), NullLogger<ReleaseNotificationWorker>.Instance);

        await Tick(worker);
        Assert.Equal(42, (await db.Context.ReleaseNotifications.SingleAsync()).TmdbId);
        await Tick(worker);
        await Tick(worker);

        Assert.Equal(2, sends);
        Assert.Equal(2, await db.Context.ReleaseNotifications.CountAsync());
    }

    [Fact]
    public async Task OngoingSeasonOlderThanThirtyDaysIncludesLaterEpisodes()
    {
        await using var db = new TestDatabase();
        DateOnly today = new(2026, 11, 13);
        var episode = new { season_number = 1, episode_number = 10, name = "Dix", air_date = today.ToString("yyyy-MM-dd") };
        using var http = new HttpClient(new StubHandler((request, _) =>
            request.RequestUri!.AbsolutePath.EndsWith("/season/1")
                ? Json(new { episodes = new[] { episode, new { season_number = 1, episode_number = 11, name = "Onze", air_date = today.AddDays(7).ToString("yyyy-MM-dd") } } })
                : Json(new
                {
                    name = "Série", next_episode_to_air = episode,
                    seasons = new[] { new { season_number = 1, air_date = today.AddDays(-70).ToString("yyyy-MM-dd") } }
                })));
        var service = new TmdbReleaseService(http, db.Context, Configuration(), NullLogger<TmdbReleaseService>.Instance);

        var releases = await service.GetUpcomingReleases(new(42, MediaType.Show, "Série", null), today, 14, CancellationToken.None);

        Assert.Equal(2, releases.Count);
        Assert.Contains(releases, release => release.ReleaseTitle.Contains("S01E11"));
    }

    [Fact]
    public async Task TmdbCancellationIsPropagated()
    {
        await using var db = new TestDatabase();
        using var cts = new CancellationTokenSource();
        using var http = new HttpClient(new StubHandler((_, token) =>
        {
            cts.Cancel();
            token.ThrowIfCancellationRequested();
            return Json(new { });
        }));
        var service = new TmdbReleaseService(http, db.Context, Configuration(), NullLogger<TmdbReleaseService>.Instance);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            service.GetUpcomingReleases(new(42, MediaType.Movie, "Film", null), Today(), 1, cts.Token));
    }

    [Fact]
    public async Task CalendarCacheReflectsTrackingChangesAndEscapesAndFoldsUnicodeTitles()
    {
        await using var db = new TestDatabase();
        string title = string.Concat(Enumerable.Repeat("Été 🎬 ", 30)) + "\r\nSuite\rEncore, fin;";
        using var http = new HttpClient(new StubHandler((_, _) => Json(new { title, release_date = Today().ToString("yyyy-MM-dd") })));
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var config = Configuration();
        var service = new IcsCalendarService(db.Context,
            new TmdbReleaseService(http, db.Context, config, NullLogger<TmdbReleaseService>.Instance), cache, config);
        Assert.DoesNotContain("BEGIN:VEVENT", await service.BuildIcsAsync(CancellationToken.None));

        var tracked = new TrackedMediaRelease(42, MediaType.Movie, "Film", null);
        db.Context.TrackedMediaReleases.Add(tracked);
        await db.Context.SaveChangesAsync();
        string calendar = await service.BuildIcsAsync(CancellationToken.None);

        Assert.Contains("BEGIN:VEVENT", calendar);
        Assert.All(calendar.Split("\r\n"), line => Assert.True(Encoding.UTF8.GetByteCount(line) <= 75));
        Assert.Contains("\\nSuite\\nEncore\\, fin\\;", calendar.Replace("\r\n ", ""));
        Assert.DoesNotContain("\r", calendar.Replace("\r\n", ""));
        db.Context.TrackedMediaReleases.Remove(tracked);
        await db.Context.SaveChangesAsync();
        Assert.DoesNotContain("BEGIN:VEVENT", await service.BuildIcsAsync(CancellationToken.None));
    }

    [Fact]
    public async Task FailedCalendarFetchDoesNotCacheAnEmptyFeed()
    {
        await using var db = new TestDatabase();
        db.Context.TrackedMediaReleases.Add(new(42, MediaType.Movie, "Film", null));
        await db.Context.SaveChangesAsync();
        int calls = 0;
        using var http = new HttpClient(new StubHandler((_, _) => ++calls == 1
            ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
            : Json(new { title = "Film", release_date = Today().ToString("yyyy-MM-dd") })));
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var config = Configuration();
        var service = new IcsCalendarService(db.Context,
            new TmdbReleaseService(http, db.Context, config, NullLogger<TmdbReleaseService>.Instance), cache, config);

        await Assert.ThrowsAsync<HttpRequestException>(() => service.BuildIcsAsync(CancellationToken.None));
        Assert.Contains("BEGIN:VEVENT", await service.BuildIcsAsync(CancellationToken.None));
        Assert.Equal(2, calls);
    }

    [Fact]
    public async Task NotificationTitleWithNewlineIsEncodedAsSafeHeader()
    {
        string? header = null;
        using var http = new HttpClient(new StubHandler((request, _) =>
        {
            header = request.Headers.GetValues("Title").Single();
            return new HttpResponseMessage(HttpStatusCode.OK);
        }));
        var ntfy = new NtfyService(http, NullLogger<NtfyService>.Instance);
        await ntfy.SendReleaseNotification(NotificationSettings(),
            new(42, MediaType.Movie, "Title\r\ncontinued", "release", "Title", Today(), null), CancellationToken.None);

        Assert.StartsWith("=?UTF-8?B?", header);
        Assert.DoesNotContain("\r", header);
        Assert.DoesNotContain("\n", header);
    }

    private static DateOnly Today() => DateOnly.FromDateTime(DateTime.Now);

    private static AppSettings NotificationSettings() => new()
    {
        NtfyEnabled = true, NtfyUrl = "https://ntfy.invalid", NtfyTopic = "releases",
        NotificationHour = 0, NotificationMinute = 0, TmdbApiKey = "test-key"
    };

    private static IConfiguration Configuration() => new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?> { ["TMDB:ApiKey"] = "test-key" }).Build();

    private static ServiceProvider WorkerServices(ApiDbContext context, HttpClient tmdb, HttpClient ntfy)
    {
        var services = new ServiceCollection();
        services.AddScoped(_ => new ApiDbContext(new DbContextOptionsBuilder<ApiDbContext>()
            .UseSqlite(context.Database.GetDbConnection()).Options));
        services.AddScoped(sp => new TmdbReleaseService(tmdb, sp.GetRequiredService<ApiDbContext>(), Configuration(), NullLogger<TmdbReleaseService>.Instance));
        services.AddScoped(_ => new NtfyService(ntfy, NullLogger<NtfyService>.Instance));
        return services.BuildServiceProvider();
    }

    private static Task Tick(ReleaseNotificationWorker worker) =>
        (Task)typeof(ReleaseNotificationWorker).GetMethod("Tick", BindingFlags.Instance | BindingFlags.NonPublic)!
            .Invoke(worker, [CancellationToken.None])!;

    private static HttpResponseMessage Json(object body) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json")
    };

    private sealed class StubHandler(Func<HttpRequestMessage, CancellationToken, HttpResponseMessage> respond) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(respond(request, cancellationToken));
    }
}
