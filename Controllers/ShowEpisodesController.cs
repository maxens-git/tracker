using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/shows")]
public class ShowEpisodesController(
    ApiDbContext context,
    UserMediaService mediaService,
    ActivityService activityService) : ControllerBase
{
    [HttpGet("{showTmdbId}/episodes")]
    public async Task<ActionResult<List<EpisodeSeenDto>>> GetEpisodes(int showTmdbId)
    {
        List<UserEpisode> episodes = await context.UserEpisodes
            .Where(e => e.ShowTmdbId == showTmdbId && e.Seen)
            .ToListAsync();

        return episodes.Select(e => new EpisodeSeenDto(e)).ToList();
    }

    /// <summary>Séries « en cours » : au moins un épisode vu, mais série non marquée entièrement vue.</summary>
    [HttpGet("in-progress")]
    public async Task<ActionResult<List<InProgressShowDto>>> GetInProgress()
    {
        List<int> fullySeenShowIds = await context.UserMedia
            .Where(m => m.MediaType == MediaType.Show && m.Seen)
            .Select(m => m.TmdbId)
            .ToListAsync();

        List<UserEpisode> seenEpisodes = await context.UserEpisodes
            .Where(e => e.Seen && !fullySeenShowIds.Contains(e.ShowTmdbId))
            .ToListAsync();

        Dictionary<int, string?> posters = await context.UserMedia
            .Where(m => m.MediaType == MediaType.Show)
            .ToDictionaryAsync(m => m.TmdbId, m => m.PosterPath);

        return seenEpisodes
            .GroupBy(e => e.ShowTmdbId)
            .Select(g =>
            {
                UserEpisode last = g
                    .OrderByDescending(e => e.SeasonNumber)
                    .ThenByDescending(e => e.EpisodeNumber)
                    .First();
                return new InProgressShowDto
                {
                    ShowTmdbId = g.Key,
                    PosterPath = posters.GetValueOrDefault(g.Key),
                    SeenEpisodeCount = g.Count(),
                    LastSeasonNumber = last.SeasonNumber,
                    LastEpisodeNumber = last.EpisodeNumber,
                    // Le plus récemment coché en premier (AddedAt = date du marquage initial).
                    LastWatchedAt = g.Max(e => e.AddedAt),
                };
            })
            .OrderByDescending(s => s.LastWatchedAt)
            .ToList();
    }

    [HttpPost("{showTmdbId}/seen")]
    public async Task<IActionResult> MarkShowSeen(int showTmdbId, [FromBody] MarkShowSeenDto dto)
    {
        UserMedia um = await mediaService.EnsureUserMedia(showTmdbId, MediaType.Show, dto.PosterPath, genres: dto.Genres);
        um.Seen = dto.Seen;

        foreach (SeasonEpisodesDto season in dto.Seasons)
            foreach (int epNumber in season.EpisodeNumbers)
                await UpsertEpisode(showTmdbId, season.SeasonNumber, epNumber, dto.Seen);

        activityService.Log(dto.Seen ? ActivityType.MarkedSeen : ActivityType.MarkedUnseen,
                            showTmdbId, MediaType.Show, um.PosterPath);
        await context.SaveChangesAsync();
        return Ok(new { showTmdbId, seen = dto.Seen });
    }

    [HttpPost("{showTmdbId}/seasons/{seasonNumber}/seen")]
    public async Task<IActionResult> MarkSeasonSeen(int showTmdbId, int seasonNumber, [FromBody] MarkSeasonSeenDto dto)
    {
        UserMedia um = await mediaService.EnsureUserMedia(showTmdbId, MediaType.Show);

        foreach (int epNumber in dto.EpisodeNumbers)
            await UpsertEpisode(showTmdbId, seasonNumber, epNumber, dto.Seen);

        activityService.Log(dto.Seen ? ActivityType.MarkedSeasonSeen : ActivityType.MarkedSeasonUnseen,
                            showTmdbId, MediaType.Show, um.PosterPath, seasonNumber: seasonNumber);
        await context.SaveChangesAsync();
        return Ok(new { showTmdbId, seasonNumber, seen = dto.Seen });
    }

    [HttpPost("{showTmdbId}/seasons/{seasonNumber}/episodes/{episodeNumber}/seen")]
    public async Task<IActionResult> MarkEpisodeSeen(int showTmdbId, int seasonNumber, int episodeNumber, [FromBody] bool seen)
    {
        UserMedia um = await mediaService.EnsureUserMedia(showTmdbId, MediaType.Show);
        await UpsertEpisode(showTmdbId, seasonNumber, episodeNumber, seen);

        activityService.Log(seen ? ActivityType.MarkedEpisodeSeen : ActivityType.MarkedEpisodeUnseen,
                            showTmdbId, MediaType.Show, um.PosterPath,
                            seasonNumber: seasonNumber, episodeNumber: episodeNumber);
        await context.SaveChangesAsync();

        return Ok(new { showTmdbId, seasonNumber, episodeNumber, seen });
    }

    /// <summary>Crée ou met à jour l'état "vu" d'un épisode (sans sauvegarder : l'appelant le fait).</summary>
    private async Task UpsertEpisode(int showTmdbId, int seasonNumber, int episodeNumber, bool seen)
    {
        UserEpisode? ep = await context.UserEpisodes
            .FirstOrDefaultAsync(e => e.ShowTmdbId == showTmdbId && e.SeasonNumber == seasonNumber && e.EpisodeNumber == episodeNumber);

        if (ep == null)
            context.UserEpisodes.Add(new UserEpisode(showTmdbId, seasonNumber, episodeNumber, seen));
        else
            ep.Seen = seen;
    }
}
