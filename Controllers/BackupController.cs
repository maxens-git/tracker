using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BackupController(BackupService backups) : ControllerBase
{
    private const long MaxImportSize = 512L * 1024 * 1024;

    /// <summary>Télécharge toute la base au format JSON. Les logs système sont optionnels (volumineux).</summary>
    [HttpGet("export")]
    public async Task Export([FromQuery] bool includeLogs = false, CancellationToken cancellationToken = default)
    {
        DatabaseBackup backup = await backups.Export(includeLogs, cancellationToken);

        Response.ContentType = "application/json; charset=utf-8";
        Response.Headers.ContentDisposition =
            $"attachment; filename=\"tracker-backup-{backup.ExportedAt:yyyy-MM-dd-HHmmss}.json\"";
        await JsonSerializer.SerializeAsync(Response.Body, backup, BackupService.JsonOptions, cancellationToken);
    }

    /// <summary>
    /// Remplace toute la base par le contenu d'une sauvegarde (corps = fichier JSON brut).
    /// Lu à la main pour utiliser le même format que l'export (enums en texte, sans navigations).
    /// </summary>
    [HttpPost("import")]
    [RequestSizeLimit(MaxImportSize)]
    public async Task<ActionResult<BackupImportResult>> Import(CancellationToken cancellationToken)
    {
        try
        {
            DatabaseBackup backup = await backups.Read(Request.Body, cancellationToken);
            return await backups.Import(backup, cancellationToken);
        }
        catch (BackupValidationException ex)
        {
            return BadRequest(ex.Message);
        }
    }
}
