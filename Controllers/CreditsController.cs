using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.Models.TMDbResponses;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CreditsController : ControllerBase
{
    private readonly TMDbService _tmdbService;
    private readonly ApiDbContext _context;

    public CreditsController(TMDbService tmdbService, ApiDbContext context)
    {
        _tmdbService = tmdbService;
        _context = context;
    }

    [HttpGet("movie/{tmdbId}")]
    public async Task<ActionResult<CreditsResponseDto>> GetMovieCredits(int tmdbId)
    {
        TMDbCreditsResponse? credits = await _tmdbService.GetMovieCreditsAsync(tmdbId);

        if (credits == null)
        {
            return NotFound();
        }

        // Sauvegarder les credits dans la base de données
        await SaveMovieCreditsAsync(tmdbId, credits);

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

        // Sauvegarder les credits dans la base de données
        await SaveShowCreditsAsync(tmdbId, credits);

        return Ok(MapToDto(tmdbId, credits));
    }

    private async Task SaveMovieCreditsAsync(int tmdbId, TMDbCreditsResponse credits)
    {
        var movie = await _context.Movies.FirstOrDefaultAsync(m => m.TmdbId == tmdbId);
        if (movie == null) return;

        // Sauvegarder le cast
        if (credits.Cast != null)
        {
            var castToSave = credits.Cast.OrderBy(c => c.Order).Take(20).ToList();
            foreach (var castMember in castToSave)
            {
                var person = await GetOrCreatePersonAsync(castMember.Id, castMember.Name, castMember.ProfilePath, castMember.KnownForDepartment, castMember.Gender, castMember.Popularity);
                
                var existingCast = await _context.MovieCasts
                    .FirstOrDefaultAsync(mc => mc.MovieId == movie.Id && mc.PersonId == person.Id);
                
                if (existingCast == null)
                {
                    _context.MovieCasts.Add(new MovieCast
                    {
                        MovieId = movie.Id,
                        PersonId = person.Id,
                        Character = castMember.Character,
                        Order = castMember.Order
                    });
                }
            }
        }

        // Sauvegarder le crew
        if (credits.Crew != null)
        {
            var crewToSave = credits.Crew
                .Where(c => c.Job == "Director" || c.Job == "Writer" || c.Job == "Screenplay" || c.Job == "Producer" || c.Job == "Executive Producer" || c.Job == "Original Music Composer")
                .GroupBy(c => new { c.Id, c.Job })
                .Select(g => g.First())
                .OrderByDescending(c => c.Popularity)
                .Take(10)
                .ToList();

            foreach (var crewMember in crewToSave)
            {
                var person = await GetOrCreatePersonAsync(crewMember.Id, crewMember.Name, crewMember.ProfilePath, crewMember.KnownForDepartment, crewMember.Gender, crewMember.Popularity);
                
                var existingCrew = await _context.MovieCrews
                    .FirstOrDefaultAsync(mc => mc.MovieId == movie.Id && mc.PersonId == person.Id && mc.Job == crewMember.Job);
                
                if (existingCrew == null)
                {
                    _context.MovieCrews.Add(new MovieCrew
                    {
                        MovieId = movie.Id,
                        PersonId = person.Id,
                        Job = crewMember.Job,
                        Department = crewMember.Department
                    });
                }
            }
        }

        await _context.SaveChangesAsync();
    }

    private async Task SaveShowCreditsAsync(int tmdbId, TMDbCreditsResponse credits)
    {
        var show = await _context.Shows.FirstOrDefaultAsync(s => s.TmdbId == tmdbId);
        if (show == null) return;

        // Sauvegarder le cast
        if (credits.Cast != null)
        {
            var castToSave = credits.Cast.OrderBy(c => c.Order).Take(20).ToList();
            foreach (var castMember in castToSave)
            {
                var person = await GetOrCreatePersonAsync(castMember.Id, castMember.Name, castMember.ProfilePath, castMember.KnownForDepartment, castMember.Gender, castMember.Popularity);
                
                var existingCast = await _context.ShowCasts
                    .FirstOrDefaultAsync(sc => sc.ShowId == show.Id && sc.PersonId == person.Id);
                
                if (existingCast == null)
                {
                    _context.ShowCasts.Add(new ShowCast
                    {
                        ShowId = show.Id,
                        PersonId = person.Id,
                        Character = castMember.Character,
                        Order = castMember.Order
                    });
                }
            }
        }

        // Sauvegarder le crew
        if (credits.Crew != null)
        {
            var crewToSave = credits.Crew
                .Where(c => c.Job == "Director" || c.Job == "Writer" || c.Job == "Screenplay" || c.Job == "Producer" || c.Job == "Executive Producer" || c.Job == "Original Music Composer")
                .GroupBy(c => new { c.Id, c.Job })
                .Select(g => g.First())
                .OrderByDescending(c => c.Popularity)
                .Take(10)
                .ToList();

            foreach (var crewMember in crewToSave)
            {
                var person = await GetOrCreatePersonAsync(crewMember.Id, crewMember.Name, crewMember.ProfilePath, crewMember.KnownForDepartment, crewMember.Gender, crewMember.Popularity);
                
                var existingCrew = await _context.ShowCrews
                    .FirstOrDefaultAsync(sc => sc.ShowId == show.Id && sc.PersonId == person.Id && sc.Job == crewMember.Job);
                
                if (existingCrew == null)
                {
                    _context.ShowCrews.Add(new ShowCrew
                    {
                        ShowId = show.Id,
                        PersonId = person.Id,
                        Job = crewMember.Job,
                        Department = crewMember.Department
                    });
                }
            }
        }

        await _context.SaveChangesAsync();
    }

    private async Task<Person> GetOrCreatePersonAsync(int tmdbId, string? name, string? profilePath, string? knownForDepartment, int gender, double popularity)
    {
        var person = await _context.Persons.FirstOrDefaultAsync(p => p.TmdbId == tmdbId);
        
        if (person == null)
        {
            person = new Person
            {
                TmdbId = tmdbId,
                Name = name ?? string.Empty,
                ProfilePath = profilePath,
                KnownForDepartment = knownForDepartment,
                Gender = gender,
                Popularity = popularity,
                AddedAt = DateTime.UtcNow
            };
            _context.Persons.Add(person);
            await _context.SaveChangesAsync();
        }
        
        return person;
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
