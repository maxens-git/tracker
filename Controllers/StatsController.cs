using Microsoft.AspNetCore.Mvc;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StatsController(StatsService statsService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<StatsDto>> Get() => await statsService.GetStats();
}
