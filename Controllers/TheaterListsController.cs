using Microsoft.AspNetCore.Mvc;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

/// <summary>
/// Listes de cinémas : regrouper des salles Allociné pour consulter leurs séances ensemble,
/// et en marquer une « par défaut » (chargée à l'ouverture de la page Séances).
/// </summary>
[ApiController]
[Route("api/theater-lists")]
public class TheaterListsController(TheaterListService lists) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<TheaterListDto>>> GetAll() =>
        Ok(await lists.GetAll());

    [HttpGet("{id:int}")]
    public async Task<ActionResult<TheaterListDto>> Get(int id)
    {
        TheaterListDto? list = await lists.Get(id);
        return list is null ? NotFound() : Ok(list);
    }

    [HttpPost]
    public async Task<ActionResult<TheaterListDto>> Create([FromBody] TheaterListSaveDto dto)
    {
        try
        {
            TheaterListDto created = await lists.Create(dto);
            return CreatedAtAction(nameof(Get), new { id = created.Id }, created);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<TheaterListDto>> Update(int id, [FromBody] TheaterListSaveDto dto)
    {
        try
        {
            TheaterListDto? updated = await lists.Update(id, dto);
            return updated is null ? NotFound() : Ok(updated);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id) =>
        await lists.Delete(id) ? NoContent() : NotFound();

    [HttpPut("{id:int}/default")]
    public async Task<IActionResult> SetDefault(int id) =>
        await lists.SetDefault(id) ? NoContent() : NotFound();
}
