using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.Models.TMDbResponses;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ShowsController : ControllerBase
{
    private readonly ApiDbContext _context;
    private readonly TMDbService _tmdbService;

    public ShowsController(ApiDbContext context, TMDbService tmdbService)
    {
        _context = context;
        _tmdbService = tmdbService;
    }

    [HttpGet("{tmdbId}")]
    public async Task<ActionResult<Show>> GetByTmdbId(int tmdbId)
    {
        Show? show = await _context.Shows
            .Include(s => s.Seasons)
                .ThenInclude(s => s.Episodes)
            .FirstOrDefaultAsync(s => s.TmdbId == tmdbId);

        if (show == null)
        {
            TMDbShowResponse? tmdbShow = await _tmdbService.GetShowAsync(tmdbId);
            if (tmdbShow == null)
                return NotFound("Show not found on TMDb");

            show = new Show
            {
                TmdbId = tmdbShow.Id,
                Title = tmdbShow.Name,
                OriginalTitle = tmdbShow.OriginalName,
                Overview = tmdbShow.Overview,
                Status = tmdbShow.Status,
                Tagline = tmdbShow.Tagline,
                PosterPath = tmdbShow.PosterPath,
                BackdropPath = tmdbShow.BackdropPath,
                VoteAverage = tmdbShow.VoteAverage,
                VoteCount = tmdbShow.VoteCount,
                Popularity = tmdbShow.Popularity,
                ReleaseDate = ParseDate(tmdbShow.FirstAirDate),
                LastAirDate = ParseDate(tmdbShow.LastAirDate),
                NumberOfSeasons = tmdbShow.NumberOfSeasons,
                NumberOfEpisodes = tmdbShow.NumberOfEpisodes,
                Genres = string.Join(", ", tmdbShow.Genres.Select(g => g.Name))
            };

            _context.Shows.Add(show);
            await _context.SaveChangesAsync();

            foreach (TMDbSeasonSummary seasonSummary in tmdbShow.Seasons)
            {
                TMDbSeasonResponse? tmdbSeason = await _tmdbService.GetSeasonAsync(tmdbId, seasonSummary.SeasonNumber);
                if (tmdbSeason == null) continue;

                Season season = new Season
                {
                    TmdbId = tmdbSeason.Id,
                    Name = tmdbSeason.Name,
                    Overview = tmdbSeason.Overview,
                    SeasonNumber = tmdbSeason.SeasonNumber,
                    EpisodeCount = tmdbSeason.Episodes.Count,
                    AirDate = ParseDate(tmdbSeason.AirDate),
                    PosterPath = tmdbSeason.PosterPath,
                    ShowId = show.Id
                };

                _context.Seasons.Add(season);
                await _context.SaveChangesAsync();

                foreach (TMDbEpisodeResponse tmdbEpisode in tmdbSeason.Episodes)
                {
                    Episode episode = new Episode
                    {
                        TmdbId = tmdbEpisode.Id,
                        Name = tmdbEpisode.Name,
                        Overview = tmdbEpisode.Overview,
                        EpisodeNumber = tmdbEpisode.EpisodeNumber,
                        Runtime = tmdbEpisode.Runtime ?? 0,
                        VoteAverage = tmdbEpisode.VoteAverage,
                        AirDate = ParseDate(tmdbEpisode.AirDate),
                        StillPath = tmdbEpisode.StillPath,
                        SeasonId = season.Id
                    };

                    _context.Episodes.Add(episode);
                }

                await _context.SaveChangesAsync();
            }

            show = await _context.Shows
                .Include(s => s.Seasons)
                    .ThenInclude(s => s.Episodes)
                .FirstAsync(s => s.Id == show.Id);
        }

        return show;
    }

    private static DateTime? ParseDate(string? dateString)
    {
        if (string.IsNullOrEmpty(dateString))
            return null;
        return DateTime.TryParse(dateString, out DateTime date) ? date : null;
    }
}
