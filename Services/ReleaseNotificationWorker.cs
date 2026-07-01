using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;

namespace Tracker.Services;

public class ReleaseNotificationWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<ReleaseNotificationWorker> logger) : BackgroundService
{
    private DateOnly? lastRunDate;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            await Tick(stoppingToken);
            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }

    /// <summary>
    /// Un cycle complet : lit les réglages une fois, vérifie qu'on est dans la fenêtre
    /// d'envoi du jour, puis notifie les sorties à venir. Tout se fait dans un seul scope.
    /// </summary>
    private async Task Tick(CancellationToken cancellationToken)
    {
        try
        {
            using IServiceScope scope = scopeFactory.CreateScope();
            ApiDbContext context = scope.ServiceProvider.GetRequiredService<ApiDbContext>();

            AppSettings? settings = await context.Settings.FirstOrDefaultAsync(s => s.Id == 1, cancellationToken);
            DateOnly today = DateOnly.FromDateTime(DateTime.Now);
            if (!ShouldRunNow(settings, today))
                return;

            logger.LogInformation("Cycle de notifications de sorties démarré pour {Date}.", today);

            TmdbReleaseService tmdb = scope.ServiceProvider.GetRequiredService<TmdbReleaseService>();
            NtfyService ntfy = scope.ServiceProvider.GetRequiredService<NtfyService>();
            await NotifyUpcoming(context, tmdb, ntfy, settings!, today, cancellationToken);
            await DetectNewSeasons(context, tmdb, ntfy, settings!, today, cancellationToken);

            lastRunDate = today;
            logger.LogInformation("Cycle de notifications de sorties terminé pour {Date}.", today);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Cycle de notifications de sorties échoué.");
        }
    }

    private bool ShouldRunNow(AppSettings? settings, DateOnly today)
    {
        if (settings == null || !settings.NtfyEnabled
            || string.IsNullOrWhiteSpace(settings.NtfyUrl) || string.IsNullOrWhiteSpace(settings.NtfyTopic))
            return false;

        if (lastRunDate == today)
            return false;

        TimeOnly configuredTime = new(
            Math.Clamp(settings.NotificationHour, 0, 23),
            Math.Clamp(settings.NotificationMinute, 0, 59));

        return TimeOnly.FromDateTime(DateTime.Now) >= configuredTime;
    }

    private async Task NotifyUpcoming(
        ApiDbContext context,
        TmdbReleaseService tmdb,
        NtfyService ntfy,
        AppSettings settings,
        DateOnly today,
        CancellationToken cancellationToken)
    {
        List<TrackedMediaRelease> tracked = await context.TrackedMediaReleases.ToListAsync(cancellationToken);
        int daysAhead = Math.Clamp(settings.NotifyDaysAhead, 0, 30);
        logger.LogInformation("Vérification des sorties à venir: {Count} médias suivis, fenêtre {DaysAhead} jours.",
            tracked.Count, daysAhead);

        foreach (TrackedMediaRelease media in tracked)
        {
            List<ReleaseCandidate> releases = await tmdb.GetUpcomingReleases(media, today, daysAhead, cancellationToken);
            if (releases.Count > 0)
            {
                logger.LogInformation("{Count} sortie(s) détectée(s) pour {Title} ({Type} {TmdbId}).",
                    releases.Count, media.Title, media.MediaType, media.TmdbId);
            }

            foreach (ReleaseCandidate release in releases)
            {
                bool alreadySent = await context.ReleaseNotifications.AnyAsync(n =>
                    n.TmdbId == release.TmdbId &&
                    n.MediaType == release.MediaType &&
                    n.ReleaseKey == release.ReleaseKey,
                    cancellationToken);

                if (alreadySent) continue;

                // Un envoi en échec (ntfy momentanément indisponible…) ne doit pas
                // interrompre le reste du cycle : on logue et on passe au suivant.
                try
                {
                    await ntfy.SendReleaseNotification(settings, release, cancellationToken);
                    context.ReleaseNotifications.Add(new ReleaseNotification(release.TmdbId, release.MediaType, release.ReleaseKey));
                    await context.SaveChangesAsync(cancellationToken);
                    logger.LogInformation("Notification de sortie enregistrée comme envoyée: {ReleaseTitle} ({ReleaseKey}).",
                        release.ReleaseTitle, release.ReleaseKey);
                }
                catch (OperationCanceledException)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Notification de sortie échouée pour {Type} {TmdbId} ({ReleaseKey}).",
                        release.MediaType, release.TmdbId, release.ReleaseKey);
                }
            }
        }
    }

    /// <summary>
    /// Synchronise l'instantané des saisons connues (table <c>KnownSeasons</c>) avec
    /// TMDB et notifie les saisons qui viennent d'apparaître. La première rencontre
    /// d'une série (aucune saison mémorisée) ne fait que semer l'instantané sans
    /// notifier — sinon chaque saison existante déclencherait une fausse alerte.
    /// </summary>
    private async Task DetectNewSeasons(
        ApiDbContext context,
        TmdbReleaseService tmdb,
        NtfyService ntfy,
        AppSettings settings,
        DateOnly today,
        CancellationToken cancellationToken)
    {
        List<TrackedMediaRelease> shows = await context.TrackedMediaReleases
            .Where(m => m.MediaType == MediaType.Show)
            .ToListAsync(cancellationToken);
        logger.LogInformation("Vérification des nouvelles saisons: {Count} série(s) suivie(s).", shows.Count);

        foreach (TrackedMediaRelease media in shows)
        {
            List<SeasonInfo> seasons = await tmdb.GetShowSeasons(media.TmdbId, cancellationToken);
            if (seasons.Count == 0) continue;

            List<KnownSeason> known = await context.KnownSeasons
                .Where(s => s.TmdbId == media.TmdbId)
                .ToListAsync(cancellationToken);
            Dictionary<int, KnownSeason> knownByNumber = known.ToDictionary(k => k.SeasonNumber);

            // Aucune saison mémorisée = première rencontre : on sème sans notifier.
            bool seeding = known.Count == 0;
            if (seeding)
            {
                logger.LogInformation("Initialisation des saisons connues pour {Title} ({TmdbId}): {Count} saison(s).",
                    media.Title, media.TmdbId, seasons.Count);
            }

            foreach (SeasonInfo season in seasons)
            {
                if (knownByNumber.TryGetValue(season.SeasonNumber, out KnownSeason? existing))
                {
                    existing.SeasonName = season.Name;
                    existing.AirDate = season.AirDate;
                    existing.EpisodeCount = season.EpisodeCount;
                    existing.LastCheckedAt = DateTime.UtcNow;
                    continue;
                }

                context.KnownSeasons.Add(new KnownSeason(
                    media.TmdbId, season.SeasonNumber, season.Name, season.AirDate, season.EpisodeCount));

                if (seeding || !IsUpcoming(season.AirDate, today)) continue;

                try
                {
                    logger.LogInformation("Nouvelle saison à notifier: {Title} S{Season} (air date: {AirDate}).",
                        media.Title, season.SeasonNumber, season.AirDate ?? "à confirmer");
                    await ntfy.SendSeasonAnnouncedNotification(
                        settings, media.Title, $"{media.Title} — saison {season.SeasonNumber}", season.AirDate, cancellationToken);
                    logger.LogInformation("Notification de nouvelle saison envoyée pour {Title} S{Season}.",
                        media.Title, season.SeasonNumber);
                }
                catch (OperationCanceledException)
                {
                    throw;
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "Notification de nouvelle saison échouée pour {TmdbId} S{Season}.",
                        media.TmdbId, season.SeasonNumber);
                }
            }

            await context.SaveChangesAsync(cancellationToken);
        }
    }

    /// <summary>Une saison est « à venir » si elle n'a pas de date, ou une date non passée.</summary>
    private static bool IsUpcoming(string? airDate, DateOnly today) =>
        !DateOnly.TryParseExact(airDate, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out DateOnly date)
        || date >= today;
}
