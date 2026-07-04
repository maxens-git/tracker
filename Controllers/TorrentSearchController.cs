using Microsoft.AspNetCore.Mvc;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/torrents")]
public class TorrentSearchController(
    ProwlarrService prowlarr,
    AllDebridService allDebrid,
    ILogger<TorrentSearchController> logger) : ControllerBase
{
    [HttpGet("indexers")]
    public Task<ActionResult<List<IndexerDto>>> Indexers(CancellationToken cancellationToken) =>
        Guarded("Prowlarr", "Récupération des indexeurs Prowlarr échouée.",
            () => prowlarr.GetIndexers(cancellationToken));

    [HttpGet("categories")]
    public Task<ActionResult<List<CategoryDto>>> Categories(CancellationToken cancellationToken) =>
        Guarded("Prowlarr", "Récupération des catégories Prowlarr échouée.",
            () => prowlarr.GetCategories(cancellationToken));

    [HttpGet("search")]
    public Task<ActionResult<List<TorrentResultDto>>> Search(
        [FromQuery] string query,
        [FromQuery] int[]? indexerIds,
        [FromQuery] int? categoryId,
        CancellationToken cancellationToken) =>
        Guarded("Prowlarr", $"Recherche Prowlarr échouée pour « {query} ».",
            () => prowlarr.Search(query, indexerIds, categoryId, cancellationToken));

    [HttpPost("debrid")]
    public Task<ActionResult<DebridResultDto>> Debrid(DebridRequestDto request, CancellationToken cancellationToken) =>
        Guarded("AllDebrid", "Débridage AllDebrid échoué.",
            () => allDebrid.Debrid(request.Magnet, cancellationToken));

    [HttpPost("unlock")]
    public Task<ActionResult<UnlockResultDto>> Unlock(UnlockRequestDto request, CancellationToken cancellationToken) =>
        Guarded("AllDebrid", "Unlock AllDebrid échoué.",
            () => allDebrid.Unlock(request.Link, cancellationToken));

    /// <summary>
    /// Exécute un appel à un service externe et traduit les échecs en réponses HTTP cohérentes :
    /// non configuré / entrée invalide → 400, torrent non caché → 409, service injoignable → 502.
    /// </summary>
    private async Task<ActionResult<T>> Guarded<T>(string service, string failureLog, Func<Task<T>> action)
    {
        try
        {
            return await action();
        }
        catch (AllDebridService.NotCachedException ex)
        {
            return Conflict(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "{FailureLog}", failureLog);
            return StatusCode(StatusCodes.Status502BadGateway, $"{service} est injoignable.");
        }
    }
}
