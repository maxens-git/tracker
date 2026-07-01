using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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
        AppSettings settings = await EnsureSettings();
        settings.NtfyEnabled = dto.NtfyEnabled;
        settings.NtfyUrl = dto.NtfyUrl.NullIfBlank();
        settings.NtfyTopic = dto.NtfyTopic.NullIfBlank();
        settings.NtfyToken = dto.NtfyToken.NullIfBlank();
        settings.NotifyDaysAhead = Math.Clamp(dto.NotifyDaysAhead, 0, 30);
        settings.NotificationHour = Math.Clamp(dto.NotificationHour, 0, 23);
        settings.NotificationMinute = Math.Clamp(dto.NotificationMinute, 0, 59);
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
        await ntfy.SendTestNotification(settings, cancellationToken);
        return NoContent();
    }

    private async Task<AppSettings> EnsureSettings()
    {
        AppSettings? settings = await context.Settings.FirstOrDefaultAsync(s => s.Id == 1);
        if (settings != null) return settings;

        settings = new AppSettings { Id = 1 };
        context.Settings.Add(settings);
        await context.SaveChangesAsync();
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
            settings.UpdatedAt);
}
