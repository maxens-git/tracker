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

            TmdbReleaseService tmdb = scope.ServiceProvider.GetRequiredService<TmdbReleaseService>();
            NtfyService ntfy = scope.ServiceProvider.GetRequiredService<NtfyService>();
            await NotifyUpcoming(context, tmdb, ntfy, settings!, today, cancellationToken);

            lastRunDate = today;
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

        foreach (TrackedMediaRelease media in tracked)
        {
            List<ReleaseCandidate> releases = await tmdb.GetUpcomingReleases(media, today, daysAhead, cancellationToken);
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
}
