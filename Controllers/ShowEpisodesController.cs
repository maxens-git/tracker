using System.ComponentModel.DataAnnotations;
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
    ActivityService activityService,
    WatchHistoryService watchHistoryService) : ControllerBase
{
    [HttpGet("{showTmdbId}/episodes")]
    public async Task<ActionResult<List<EpisodeSeenDto>>> GetEpisodes([Range(1, int.MaxValue)] int showTmdbId)
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

        List<int> seenEpisodeIds = seenEpisodes.Select(e => e.Id).ToList();
        Dictionary<int, DateTime> lastWatchedByEpisodeId = await context.UserEpisodeWatchEvents
            .Where(w => seenEpisodeIds.Contains(w.UserEpisodeId))
            .GroupBy(w => w.UserEpisodeId)
            .Select(g => new { EpisodeId = g.Key, Last = g.Max(w => w.WatchedAt) })
            .ToDictionaryAsync(x => x.EpisodeId, x => x.Last);

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
                    LastWatchedAt = g.Max(e => lastWatchedByEpisodeId.GetValueOrDefault(e.Id, e.AddedAt)),
                };
            })
            .OrderByDescending(s => s.LastWatchedAt)
            .ToList();
    }

    [HttpPost("{showTmdbId}/seen")]
    public async Task<IActionResult> MarkShowSeen([Range(1, int.MaxValue)] int showTmdbId, [FromBody] MarkShowSeenDto dto)
    {
        if (dto.Seasons == null || dto.Seasons.Any(s => s == null || s.SeasonNumber < 0
                || s.EpisodeNumbers == null || s.EpisodeNumbers.Any(n => n < 1)))
            return BadRequest("Les saisons et numéros d'épisode sont invalides.");

        UserMedia um = await mediaService.EnsureUserMedia(showTmdbId, MediaType.Show, dto.PosterPath, genres: dto.Genres, title: dto.Title);

        if (dto.Seen && um.WatchCount == 0)
            watchHistoryService.AddMovieWatch(um, DateTime.UtcNow);
        else if (!dto.Seen && um.WatchCount > 0)
            await watchHistoryService.ClearMovieWatches(um);

        foreach (SeasonEpisodesDto season in dto.Seasons)
            foreach (int epNumber in season.EpisodeNumbers)
                await UpsertEpisode(showTmdbId, season.SeasonNumber, epNumber, dto.Seen);

        activityService.Log(dto.Seen ? ActivityType.MarkedSeen : ActivityType.MarkedUnseen,
                            showTmdbId, MediaType.Show, um.PosterPath);
        await context.SaveChangesAsync();
        return Ok(new { showTmdbId, seen = dto.Seen });
    }

    [HttpPost("{showTmdbId}/seasons/{seasonNumber}/seen")]
    public async Task<IActionResult> MarkSeasonSeen([Range(1, int.MaxValue)] int showTmdbId, [Range(0, int.MaxValue)] int seasonNumber, [FromBody] MarkSeasonSeenDto dto)
    {
        if (dto.EpisodeNumbers == null || dto.EpisodeNumbers.Any(n => n < 1))
            return BadRequest("Les numéros d'épisode doivent être strictement positifs.");

        UserMedia um = await mediaService.EnsureUserMedia(showTmdbId, MediaType.Show);

        foreach (int epNumber in dto.EpisodeNumbers)
            await UpsertEpisode(showTmdbId, seasonNumber, epNumber, dto.Seen);

        activityService.Log(dto.Seen ? ActivityType.MarkedSeasonSeen : ActivityType.MarkedSeasonUnseen,
                            showTmdbId, MediaType.Show, um.PosterPath, seasonNumber: seasonNumber);
        await context.SaveChangesAsync();
        return Ok(new { showTmdbId, seasonNumber, seen = dto.Seen });
    }

    [HttpPost("{showTmdbId}/seasons/{seasonNumber}/episodes/{episodeNumber}/seen")]
    public async Task<IActionResult> MarkEpisodeSeen([Range(1, int.MaxValue)] int showTmdbId, [Range(0, int.MaxValue)] int seasonNumber, [Range(1, int.MaxValue)] int episodeNumber, [FromBody] bool seen)
    {
        UserMedia um = await mediaService.EnsureUserMedia(showTmdbId, MediaType.Show);
        await UpsertEpisode(showTmdbId, seasonNumber, episodeNumber, seen);

        activityService.Log(seen ? ActivityType.MarkedEpisodeSeen : ActivityType.MarkedEpisodeUnseen,
                            showTmdbId, MediaType.Show, um.PosterPath,
                            seasonNumber: seasonNumber, episodeNumber: episodeNumber);
        await context.SaveChangesAsync();

        return Ok(new { showTmdbId, seasonNumber, episodeNumber, seen });
    }

    [HttpGet("{showTmdbId}/seasons/{seasonNumber}/episodes/{episodeNumber}/watches")]
    public async Task<ActionResult<List<WatchEventDto>>> GetEpisodeWatches([Range(1, int.MaxValue)] int showTmdbId, [Range(0, int.MaxValue)] int seasonNumber, [Range(1, int.MaxValue)] int episodeNumber)
    {
        UserEpisode? ep = await FindEpisode(showTmdbId, seasonNumber, episodeNumber);
        if (ep == null) return new List<WatchEventDto>();

        List<UserEpisodeWatchEvent> events = await watchHistoryService.GetEpisodeWatchHistory(ep.Id);
        return events.Select(e => new WatchEventDto(e)).ToList();
    }

    /// <summary>Ajoute un visionnage d'épisode à une date choisie par l'utilisateur.</summary>
    [HttpPost("{showTmdbId}/seasons/{seasonNumber}/episodes/{episodeNumber}/watches")]
    public async Task<ActionResult<WatchEventDto>> AddEpisodeWatch(
        [Range(1, int.MaxValue)] int showTmdbId, [Range(0, int.MaxValue)] int seasonNumber, [Range(1, int.MaxValue)] int episodeNumber, [FromBody] AddEpisodeWatchDto dto)
    {
        UserMedia um = await mediaService.EnsureUserMedia(showTmdbId, MediaType.Show);
        UserEpisode ep = await EnsureEpisode(showTmdbId, seasonNumber, episodeNumber);
        bool wasSeen = ep.WatchCount > 0;

        UserEpisodeWatchEvent ev = watchHistoryService.AddEpisodeWatch(ep, dto.WatchedAt);
        activityService.Log(wasSeen ? ActivityType.EpisodeRewatched : ActivityType.MarkedEpisodeSeen,
                            showTmdbId, MediaType.Show, um.PosterPath,
                            seasonNumber: seasonNumber, episodeNumber: episodeNumber);

        await context.SaveChangesAsync();
        return Ok(new WatchEventDto(ev));
    }

    /// <summary>Supprime un visionnage d'épisode précis de l'historique.</summary>
    [HttpDelete("{showTmdbId}/seasons/{seasonNumber}/episodes/{episodeNumber}/watches/{watchId}")]
    public async Task<IActionResult> DeleteEpisodeWatch([Range(1, int.MaxValue)] int showTmdbId, [Range(0, int.MaxValue)] int seasonNumber, [Range(1, int.MaxValue)] int episodeNumber, int watchId)
    {
        UserMedia um = await mediaService.EnsureUserMedia(showTmdbId, MediaType.Show);
        UserEpisode? ep = await FindEpisode(showTmdbId, seasonNumber, episodeNumber);
        if (ep == null) return NotFound();

        bool removed = await watchHistoryService.RemoveEpisodeWatch(ep, watchId);
        if (!removed) return NotFound("Visionnage introuvable");

        if (ep.WatchCount == 0)
            activityService.Log(ActivityType.MarkedEpisodeUnseen, showTmdbId, MediaType.Show, um.PosterPath,
                                seasonNumber: seasonNumber, episodeNumber: episodeNumber);

        await context.SaveChangesAsync();
        return Ok(new { showTmdbId, seasonNumber, episodeNumber, seen = ep.Seen, watchCount = ep.WatchCount });
    }

    private async Task<UserEpisode?> FindEpisode(int showTmdbId, int seasonNumber, int episodeNumber) =>
        context.UserEpisodes.Local.FirstOrDefault(e =>
            e.ShowTmdbId == showTmdbId && e.SeasonNumber == seasonNumber && e.EpisodeNumber == episodeNumber)
        ?? await context.UserEpisodes.FirstOrDefaultAsync(e =>
            e.ShowTmdbId == showTmdbId && e.SeasonNumber == seasonNumber && e.EpisodeNumber == episodeNumber);

    /// <summary>Récupère l'épisode ou le crée ; l'appelant sauvegarde toute l'opération en une fois.</summary>
    private async Task<UserEpisode> EnsureEpisode(int showTmdbId, int seasonNumber, int episodeNumber)
    {
        UserEpisode? ep = await FindEpisode(showTmdbId, seasonNumber, episodeNumber);
        if (ep != null) return ep;

        ep = new UserEpisode(showTmdbId, seasonNumber, episodeNumber, seen: false);
        context.UserEpisodes.Add(ep);
        return ep;
    }

    /// <summary>Crée ou met à jour l'état "vu" d'un épisode (sans sauvegarder l'appel courant : l'appelant le fait).</summary>
    private async Task UpsertEpisode(int showTmdbId, int seasonNumber, int episodeNumber, bool seen)
    {
        UserEpisode ep = await EnsureEpisode(showTmdbId, seasonNumber, episodeNumber);

        if (seen && ep.WatchCount == 0)
            watchHistoryService.AddEpisodeWatch(ep, DateTime.UtcNow);
        else if (!seen && ep.WatchCount > 0)
            await watchHistoryService.ClearEpisodeWatches(ep);
    }
}
