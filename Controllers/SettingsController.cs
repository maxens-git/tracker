using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using MySqlConnector;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SettingsController(
    ApiDbContext context,
    NtfyService ntfy,
    ILogger<SettingsController> logger) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<SettingsDto>> Get()
    {
        AppSettings settings = await EnsureSettings();
        return ToDto(settings);
    }

    [HttpPut]
    public async Task<ActionResult<SettingsDto>> Update(UpdateSettingsDto dto)
    {
        if (!IsValidBaseUrl(dto.NtfyUrl) || !IsValidBaseUrl(dto.ProwlarrUrl) || !IsValidBaseUrl(dto.TmdbBaseUrl))
            return BadRequest("Les URL des services doivent être des URL HTTP(S) absolues, sans paramètres ni fragment.");

        AppSettings settings = await EnsureSettings();
        settings.NtfyEnabled = dto.NtfyEnabled;
        settings.NtfyUrl = dto.NtfyUrl.NullIfBlank();
        settings.NtfyTopic = dto.NtfyTopic.NullIfBlank();
        settings.NtfyToken = dto.NtfyToken.NullIfBlank();
        settings.NotifyDaysAhead = Math.Clamp(dto.NotifyDaysAhead, 0, 30);
        settings.NotificationHour = Math.Clamp(dto.NotificationHour, 0, 23);
        settings.NotificationMinute = Math.Clamp(dto.NotificationMinute, 0, 59);
        settings.TorrentsEnabled = dto.TorrentsEnabled ?? settings.TorrentsEnabled;
        settings.ProwlarrUrl = dto.ProwlarrUrl.NullIfBlank();
        settings.ProwlarrApiKey = dto.ProwlarrApiKey.NullIfBlank();
        settings.AllDebridApiKey = dto.AllDebridApiKey.NullIfBlank();
        settings.TmdbApiKey = dto.TmdbApiKey.NullIfBlank();
        settings.TmdbBaseUrl = dto.TmdbBaseUrl.NullIfBlank();
        settings.TmdbLanguage = dto.TmdbLanguage.NullIfBlank();
        settings.UpdatedAt = DateTime.UtcNow;

        await context.SaveChangesAsync();
        logger.LogInformation(
            "Réglages enregistrés: ntfy {Enabled}, fenêtre {DaysAhead} jours, envoi à {Hour:D2}:{Minute:D2}.",
            settings.NtfyEnabled ? "activé" : "désactivé",
            settings.NotifyDaysAhead,
            settings.NotificationHour,
            settings.NotificationMinute);
        return ToDto(settings);
    }

    [HttpPost("test")]
    public async Task<IActionResult> SendTestNotification(CancellationToken cancellationToken)
    {
        AppSettings settings = await EnsureSettings();
        if (!settings.NtfyEnabled)
        {
            logger.LogWarning("Notification ntfy de test refusée: ntfy désactivé.");
            return BadRequest("Les notifications ntfy sont désactivées.");
        }

        if (string.IsNullOrWhiteSpace(settings.NtfyUrl) || string.IsNullOrWhiteSpace(settings.NtfyTopic))
        {
            logger.LogWarning("Notification ntfy de test refusée: URL ou topic manquant.");
            return BadRequest("L'URL ntfy et le topic sont requis.");
        }

        logger.LogInformation("Notification ntfy de test demandée.");
        try
        {
            await ntfy.SendTestNotification(settings, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex, "Notification ntfy de test échouée.");
            return StatusCode(StatusCodes.Status502BadGateway, "ntfy est injoignable ou a refusé la notification.");
        }
        catch (OperationCanceledException ex)
        {
            logger.LogWarning(ex, "Délai d'envoi de la notification ntfy de test dépassé.");
            return StatusCode(StatusCodes.Status502BadGateway, "ntfy n'a pas répondu à temps.");
        }
        return NoContent();
    }

    private static bool IsValidBaseUrl(string? value) =>
        string.IsNullOrWhiteSpace(value) ||
        (Uri.TryCreate(value.Trim(), UriKind.Absolute, out Uri? uri) &&
         uri.Scheme is "http" or "https" &&
         string.IsNullOrEmpty(uri.Query) && string.IsNullOrEmpty(uri.Fragment));

    private async Task<AppSettings> EnsureSettings()
    {
        AppSettings? settings = await context.Settings.FirstOrDefaultAsync(s => s.Id == 1);
        if (settings != null) return settings;

        settings = new AppSettings { Id = 1 };
        context.Settings.Add(settings);
        try
        {
            await context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (ex.InnerException is MySqlException { Number: 1062 })
        {
            context.Entry(settings).State = EntityState.Detached;
            settings = await context.Settings.FirstOrDefaultAsync(s => s.Id == 1);
            if (settings is null) throw;
        }
        return settings;
    }

    private static SettingsDto ToDto(AppSettings settings) =>
        new(
            settings.NtfyEnabled,
            settings.NtfyUrl,
            settings.NtfyTopic,
            settings.NtfyToken,
            settings.NotifyDaysAhead,
            settings.NotificationHour,
            settings.NotificationMinute,
            settings.TorrentsEnabled,
            settings.ProwlarrUrl,
            settings.ProwlarrApiKey,
            settings.AllDebridApiKey,
            settings.TmdbApiKey,
            settings.TmdbBaseUrl,
            settings.TmdbLanguage,
            settings.UpdatedAt);
}
