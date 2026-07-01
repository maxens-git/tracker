using Microsoft.AspNetCore.Mvc;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LogsController(SystemLogService logs) : ControllerBase
{
    [HttpGet]
    public Task<PaginatedResult<SystemLogDto>> Get(
        [FromQuery] int page = 1,
        [FromQuery] string? level = null,
        [FromQuery] string? search = null) =>
        logs.GetRecent(page, level, search);

    [HttpDelete]
    public async Task<IActionResult> Clear()
    {
        await logs.Clear();
        return NoContent();
    }
}
