using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Tracker.Models.TMDbResponses;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class CreditsController : ControllerBase
{
    private readonly TMDbService _tmdbService;

    public CreditsController(TMDbService tmdbService)
    {
        _tmdbService = tmdbService;
    }

    [HttpGet("movie/{tmdbId}")]
    public async Task<ActionResult<CreditsResponseDto>> GetMovieCredits(int tmdbId)
    {
        TMDbCreditsResponse? credits = await _tmdbService.GetMovieCreditsAsync(tmdbId);

        if (credits == null)
        {
            return NotFound();
        }

        return Ok(MapToDto(tmdbId, credits));
    }

    [HttpGet("show/{tmdbId}")]
    public async Task<ActionResult<CreditsResponseDto>> GetShowCredits(int tmdbId)
    {
        TMDbCreditsResponse? credits = await _tmdbService.GetShowCreditsAsync(tmdbId);

        if (credits == null)
        {
            return NotFound();
        }

        return Ok(MapToDto(tmdbId, credits));
    }

    private static CreditsResponseDto MapToDto(int tmdbId, TMDbCreditsResponse credits)
    {
        var castList = credits.Cast?
            .OrderBy(c => c.Order)
            .Take(20)
            .Select(c => new CastMemberDto
            {
                Id = c.Id,
                Name = c.Name ?? string.Empty,
                Character = c.Character,
                ProfilePath = c.ProfilePath,
                Order = c.Order,
                KnownForDepartment = c.KnownForDepartment
            })
            .ToList() ?? new List<CastMemberDto>();

        var crewList = credits.Crew?
            .Where(c => c.Job == "Director" || c.Job == "Writer" || c.Job == "Screenplay" || c.Job == "Producer" || c.Job == "Executive Producer" || c.Job == "Original Music Composer")
            .GroupBy(c => c.Id)
            .Select(g => g.First())
            .OrderByDescending(c => c.Popularity)
            .Take(10)
            .Select(c => new CrewMemberDto
            {
                Id = c.Id,
                Name = c.Name ?? string.Empty,
                Job = c.Job,
                Department = c.Department,
                ProfilePath = c.ProfilePath
            })
            .ToList() ?? new List<CrewMemberDto>();

        return new CreditsResponseDto
        {
            TmdbId = tmdbId,
            Cast = castList,
            Crew = crewList
        };
    }
}
