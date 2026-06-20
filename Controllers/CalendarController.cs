using Microsoft.AspNetCore.Mvc;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CalendarController(IcsCalendarService calendar, IConfiguration configuration) : ControllerBase
{
    /// <summary>Jeton optionnel (config <c>Calendar:FeedToken</c>) protégeant le flux ; <c>null</c> = flux ouvert.</summary>
    private string? FeedToken => configuration["Calendar:FeedToken"].NullIfBlank();

    /// <summary>
    /// Flux iCalendar consommé par un abonnement webcal (lecture seule). iOS/macOS le
    /// rafraîchit périodiquement : ajout/suppression d'un suivi se répercute tout seul.
    /// </summary>
    [HttpGet("sorties.ics")]
    public async Task<IActionResult> Feed([FromQuery] string? token, CancellationToken cancellationToken)
    {
        if (FeedToken != null && token != FeedToken)
            return Unauthorized();

        string ics = await calendar.BuildIcsAsync(cancellationToken);
        return Content(ics, "text/calendar; charset=utf-8");
    }

    /// <summary>Donne aux clients l'URL d'abonnement prête à l'emploi (webcal + https).</summary>
    [HttpGet("info")]
    public ActionResult<CalendarInfoDto> Info()
    {
        string baseUrl = (configuration["Calendar:PublicBaseUrl"].NullIfBlank()
            ?? $"{Request.Scheme}://{Request.Host}").TrimEnd('/');

        string query = FeedToken != null ? $"?token={Uri.EscapeDataString(FeedToken)}" : string.Empty;
        string httpsUrl = $"{baseUrl}/api/calendar/sorties.ics{query}";

        return new CalendarInfoDto(ToWebcal(httpsUrl), httpsUrl);
    }

    private static string ToWebcal(string url) =>
        url.StartsWith("https://") ? string.Concat("webcal://", url.AsSpan("https://".Length))
        : url.StartsWith("http://") ? string.Concat("webcal://", url.AsSpan("http://".Length))
        : url;
}
