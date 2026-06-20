using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Tracker.Data;
using Tracker.Models;

namespace Tracker.Services;

/// <summary>
/// Génère un flux iCalendar (.ics) des prochaines sorties des médias suivis,
/// destiné à un abonnement calendrier (webcal). Le contenu reflète l'état actuel
/// de la base : un média retiré disparaît du flux — donc du calendrier abonné au
/// prochain rafraîchissement. Le résultat est mis en cache pour éviter de
/// solliciter TMDB à chaque requête d'abonnement (iOS rafraîchit périodiquement).
/// </summary>
public class IcsCalendarService(
    ApiDbContext context,
    TmdbReleaseService releases,
    IMemoryCache cache,
    IConfiguration configuration)
{
    private const string CacheKey = "calendar:sorties:ics";

    private readonly int daysAhead = Math.Clamp(configuration.GetValue("Calendar:DaysAhead", 365), 1, 1000);
    private readonly int cacheMinutes = Math.Clamp(configuration.GetValue("Calendar:CacheMinutes", 180), 0, 1440);

    public async Task<string> BuildIcsAsync(CancellationToken cancellationToken)
    {
        if (cacheMinutes == 0)
            return await GenerateAsync(cancellationToken);

        return await cache.GetOrCreateAsync(CacheKey, async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(cacheMinutes);
            return await GenerateAsync(cancellationToken);
        }) ?? string.Empty;
    }

    private async Task<string> GenerateAsync(CancellationToken cancellationToken)
    {
        List<TrackedMediaRelease> tracked = await context.TrackedMediaReleases.ToListAsync(cancellationToken);
        DateOnly today = DateOnly.FromDateTime(DateTime.Now);

        List<ReleaseCandidate> candidates = [];
        foreach (TrackedMediaRelease media in tracked)
            candidates.AddRange(await releases.GetUpcomingReleases(media, today, daysAhead, cancellationToken));

        // Dédoublonnage global par clé (un même épisode peut remonter pour plusieurs médias).
        IEnumerable<ReleaseCandidate> events = candidates
            .GroupBy(c => c.ReleaseKey)
            .Select(g => g.First())
            .OrderBy(c => c.ReleaseDate);

        return Render(events);
    }

    private static string Render(IEnumerable<ReleaseCandidate> events)
    {
        StringBuilder sb = new();
        AppendLine(sb, "BEGIN:VCALENDAR");
        AppendLine(sb, "VERSION:2.0");
        AppendLine(sb, "PRODID:-//Tracker//Sorties//FR");
        AppendLine(sb, "CALSCALE:GREGORIAN");
        AppendLine(sb, "METHOD:PUBLISH");
        AppendLine(sb, "X-WR-CALNAME:Tracker — Sorties");
        AppendLine(sb, "X-WR-TIMEZONE:Europe/Paris");
        AppendLine(sb, "X-PUBLISHED-TTL:PT12H");
        AppendLine(sb, "REFRESH-INTERVAL;VALUE=DURATION:PT12H");

        string stamp = DateTime.UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'", CultureInfo.InvariantCulture);
        foreach (ReleaseCandidate ev in events)
        {
            // Événement « journée entière » : DTEND est exclusif, donc jour suivant.
            string start = ev.ReleaseDate.ToString("yyyyMMdd", CultureInfo.InvariantCulture);
            string end = ev.ReleaseDate.AddDays(1).ToString("yyyyMMdd", CultureInfo.InvariantCulture);

            AppendLine(sb, "BEGIN:VEVENT");
            // UID stable dérivé de la clé de sortie : un même événement garde le même
            // identifiant entre deux rafraîchissements (pas de doublon dans le calendrier).
            AppendLine(sb, $"UID:{Escape(ev.ReleaseKey)}@tracker.maxens.org");
            AppendLine(sb, $"DTSTAMP:{stamp}");
            AppendLine(sb, $"DTSTART;VALUE=DATE:{start}");
            AppendLine(sb, $"DTEND;VALUE=DATE:{end}");
            AppendLine(sb, $"SUMMARY:{Escape(ev.ReleaseTitle)}");
            AppendLine(sb, $"CATEGORIES:{(ev.MediaType == MediaType.Movie ? "Film" : "Série")}");
            AppendLine(sb, "TRANSP:TRANSPARENT");
            AppendLine(sb, "END:VEVENT");
        }

        AppendLine(sb, "END:VCALENDAR");
        return sb.ToString();
    }

    // RFC 5545 : chaque ligne de contenu se termine par CRLF.
    private static void AppendLine(StringBuilder sb, string line) => sb.Append(line).Append("\r\n");

    // RFC 5545 : échappement des caractères spéciaux dans les valeurs texte.
    private static string Escape(string value) => value
        .Replace("\\", "\\\\")
        .Replace(";", "\\;")
        .Replace(",", "\\,")
        .Replace("\n", "\\n");
}
