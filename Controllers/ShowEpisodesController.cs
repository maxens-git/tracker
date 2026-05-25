using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Controllers;

[ApiController]
[Route("api/shows")]
public class ShowEpisodesController : ControllerBase
{
    private readonly ApiDbContext _context;

    public ShowEpisodesController(ApiDbContext context)
    {
        _context = context;
    }

    [HttpGet("{showTmdbId}/episodes")]
    public async Task<ActionResult<List<EpisodeSeenDto>>> GetEpisodes(int showTmdbId)
    {
        List<UserEpisode> episodes = await _context.UserEpisodes
            .Where(e => e.ShowTmdbId == showTmdbId && e.Seen)
            .ToListAsync();

        return episodes.Select(e => new EpisodeSeenDto(e)).ToList();
    }

    [HttpPost("{showTmdbId}/seen")]
    public async Task<IActionResult> MarkShowSeen(int showTmdbId, [FromBody] MarkShowSeenDto dto)
    {
        UserMedia? um = await _context.UserMedia
            .FirstOrDefaultAsync(m => m.TmdbId == showTmdbId && m.MediaType == MediaType.Show);

        if (um == null)
        {
            um = new UserMedia(showTmdbId, MediaType.Show);
            _context.UserMedia.Add(um);
        }

        um.Seen = dto.Seen;

        foreach (SeasonEpisodesDto season in dto.Seasons)
        {
            foreach (int epNumber in season.EpisodeNumbers)
            {
                await UpsertEpisode(showTmdbId, season.SeasonNumber, epNumber, dto.Seen);
            }
        }

        await _context.SaveChangesAsync();
        return Ok(new { showTmdbId, seen = dto.Seen });
    }

    [HttpPost("{showTmdbId}/seasons/{seasonNumber}/seen")]
    public async Task<IActionResult> MarkSeasonSeen(int showTmdbId, int seasonNumber, [FromBody] MarkSeasonSeenDto dto)
    {
        foreach (int epNumber in dto.EpisodeNumbers)
        {
            await UpsertEpisode(showTmdbId, seasonNumber, epNumber, dto.Seen);
        }

        await _context.SaveChangesAsync();
        return Ok(new { showTmdbId, seasonNumber, seen = dto.Seen });
    }

    [HttpPost("{showTmdbId}/seasons/{seasonNumber}/episodes/{episodeNumber}/seen")]
    public async Task<IActionResult> MarkEpisodeSeen(int showTmdbId, int seasonNumber, int episodeNumber, [FromBody] bool seen)
    {
        await UpsertEpisode(showTmdbId, seasonNumber, episodeNumber, seen);
        await _context.SaveChangesAsync();

        UserMedia? um = await _context.UserMedia
            .FirstOrDefaultAsync(m => m.TmdbId == showTmdbId && m.MediaType == MediaType.Show);

        if (um == null)
        {
            um = new UserMedia(showTmdbId, MediaType.Show);
            _context.UserMedia.Add(um);
            await _context.SaveChangesAsync();
        }

        return Ok(new { showTmdbId, seasonNumber, episodeNumber, seen });
    }

    private async Task UpsertEpisode(int showTmdbId, int seasonNumber, int episodeNumber, bool seen)
    {
        UserEpisode? ep = await _context.UserEpisodes
            .FirstOrDefaultAsync(e => e.ShowTmdbId == showTmdbId && e.SeasonNumber == seasonNumber && e.EpisodeNumber == episodeNumber);

        if (ep == null)
        {
            _context.UserEpisodes.Add(new UserEpisode(showTmdbId, seasonNumber, episodeNumber, seen));
        }
        else
        {
            ep.Seen = seen;
        }
    }
}
