using Microsoft.AspNetCore.Mvc;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

/// <summary>
/// Cinémas favoris : liste plate de salles Allociné consultées sur la page Séances, chacune
/// cochée ou non (état mémorisé). Remplace les anciennes « listes de cinémas ».
/// </summary>
[ApiController]
[Route("api/favorite-theaters")]
public class FavoriteTheatersController(FavoriteTheaterService favorites) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<FavoriteTheaterDto>>> GetAll() =>
        Ok(await favorites.GetAll());

    [HttpPost]
    public async Task<ActionResult<FavoriteTheaterDto>> Add([FromBody] FavoriteTheaterCreateDto dto)
    {
        try
        {
            FavoriteTheaterDto created = await favorites.Add(dto);
            return CreatedAtAction(nameof(GetAll), created);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Remove(int id) =>
        await favorites.Remove(id) ? NoContent() : NotFound();

    [HttpPut("{id:int}/active")]
    public async Task<IActionResult> SetActive(int id, [FromBody] FavoriteTheaterActiveDto dto) =>
        await favorites.SetActive(id, dto.IsActive) ? NoContent() : NotFound();
}
