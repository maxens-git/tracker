using Microsoft.AspNetCore.Mvc;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

/// <summary>
/// Séances de cinéma via l'API JSON interne d'Allociné.
/// Sert de proxy : Allociné n'envoie pas d'en-tête CORS, le frontend ne peut donc
/// pas l'appeler directement depuis le navigateur.
/// </summary>
[ApiController]
[Route("api/showtimes")]
public class ShowtimesController(AllocineService allocine, ILogger<ShowtimesController> logger) : ControllerBase
{
    /// <summary>
    /// Programme d'un cinéma pour une date.
    /// </summary>
    /// <param name="theater">Code cinéma Allociné, ex. « P0057 » (Pathé) ou « C0159 » (UGC).</param>
    /// <param name="date">Jour au format YYYY-MM-DD (défaut : aujourd'hui).</param>
    [HttpGet]
    public async Task<ActionResult<TheaterShowtimesDto>> Get(
        [FromQuery] string theater,
        [FromQuery] string? date,
        CancellationToken cancellationToken)
    {
        try
        {
            return await allocine.GetShowtimes(theater, date, cancellationToken);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Récupération des séances Allociné échouée (cinéma {Theater}, date {Date}).", theater, date);
            return StatusCode(StatusCodes.Status502BadGateway, "Allociné est injoignable.");
        }
    }

    /// <summary>
    /// Programme de plusieurs cinémas pour une date, pour afficher une liste de salles d'un coup.
    /// Une salle injoignable est simplement absente du résultat ; seul un code invalide renvoie 400.
    /// </summary>
    /// <param name="theaters">Codes cinéma séparés par des virgules, ex. « P0057,C0159 ».</param>
    /// <param name="date">Jour au format YYYY-MM-DD (défaut : aujourd'hui).</param>
    [HttpGet("multi")]
    public async Task<ActionResult<IReadOnlyList<TheaterShowtimesDto>>> GetMulti(
        [FromQuery] string theaters,
        [FromQuery] string? date,
        CancellationToken cancellationToken)
    {
        string[] codes = (theaters ?? "")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (codes.Length == 0)
            return BadRequest("Aucun cinéma fourni.");

        try
        {
            return Ok(await allocine.GetMultipleShowtimes(codes, date, cancellationToken));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }
}
