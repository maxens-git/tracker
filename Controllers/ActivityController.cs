using Microsoft.AspNetCore.Mvc;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ActivityController(ActivityService activityService) : ControllerBase
{
    [HttpGet]
    public Task<PaginatedResult<ActivityDto>> Get([FromQuery] int page = 1) =>
        activityService.GetRecent(page);
}
