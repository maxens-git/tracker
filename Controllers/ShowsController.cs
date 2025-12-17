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
public class ShowsController : ControllerBase
{
    private readonly ApiDbContext _context;
    private readonly TMDbService _tmdbService;
    private readonly OmdbService _omdbService;

    public ShowsController(ApiDbContext context, TMDbService tmdbService, OmdbService omdbService)
    {
        _context = context;
        _tmdbService = tmdbService;
        _omdbService = omdbService;
    }

    [HttpGet("{tmdbId}")]
    public async Task<ActionResult<ShowDto>> GetByTmdbId(int tmdbId)
    {
        Show? show = await _context.Shows
            .Include(s => s.Seasons)
                .ThenInclude(s => s.Episodes)
            .Include(s => s.MediaLists)
            .FirstOrDefaultAsync(s => s.TmdbId == tmdbId);

        if (show == null)
        {
            TMDbShowResponse? tmdbShow = await _tmdbService.GetShowAsync(tmdbId);
            if (tmdbShow == null)
                return NotFound("Show not found on TMDb");

            List<TMDbSeasonSummary> regularSeasons = tmdbShow.Seasons
                .Where(s => s.SeasonNumber > 0)
                .ToList();

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
                NumberOfSeasons = regularSeasons.Count,
                NumberOfEpisodes = 0,
                Genres = string.Join(", ", tmdbShow.Genres.Select(g => g.Name))
            };

            _context.Shows.Add(show);
            await _context.SaveChangesAsync();

            int totalEpisodeCount = 0;

            foreach (TMDbSeasonSummary seasonSummary in regularSeasons)
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

                totalEpisodeCount += tmdbSeason.Episodes.Count;

                await _context.SaveChangesAsync();
            }

            show.NumberOfEpisodes = totalEpisodeCount;
            await _context.SaveChangesAsync();

            show = await _context.Shows
                .Include(s => s.Seasons)
                    .ThenInclude(s => s.Episodes)
                .Include(s => s.MediaLists)
                .FirstAsync(s => s.Id == show.Id);
        }

        return MapToDto(show);
    }

    [HttpPost("{tmdbId}/watchlist")]
    public async Task<IActionResult> AddToWatchlist(int tmdbId)
    {
        Show? show = await _context.Shows.Include(s => s.MediaLists).FirstOrDefaultAsync(s => s.TmdbId == tmdbId);
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
        }

        MediaList? watchlist = await _context.MediaLists.Include(l => l.Shows)
            .FirstOrDefaultAsync(l => l.IsSystem && l.Name == "Watchlist");
        if (watchlist == null)
        {
            watchlist = new MediaList
            {
                Name = "Watchlist",
                IsSystem = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.MediaLists.Add(watchlist);
            await _context.SaveChangesAsync();
        }

        if (watchlist.Shows.Any(s => s.TmdbId == tmdbId))
            return BadRequest("Show already in watchlist");

        watchlist.Shows.Add(show);
        watchlist.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{tmdbId}/watchlist")]
    public async Task<IActionResult> RemoveFromWatchlist(int tmdbId)
    {
        Show? show = await _context.Shows.FirstOrDefaultAsync(s => s.TmdbId == tmdbId);
        if (show == null)
            return NotFound("Show not found");

        MediaList? watchlist = await _context.MediaLists.Include(l => l.Shows)
            .FirstOrDefaultAsync(l => l.IsSystem && l.Name == "Watchlist");
        if (watchlist == null)
            return NotFound("Watchlist not found");

        Show? existing = watchlist.Shows.FirstOrDefault(s => s.TmdbId == tmdbId || s.Id == show.Id);
        if (existing == null)
            return NotFound("Show not in watchlist");

        watchlist.Shows.Remove(existing);
        watchlist.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id}/seen")]
    public async Task<ActionResult<Show>> MarkAsSeen(int id, [FromBody] bool seen = true)
    {
        Show? show = await _context.Shows
            .Include(s => s.Seasons)
                .ThenInclude(s => s.Episodes)
            .FirstOrDefaultAsync(s => s.Id == id);
            
        if (show == null)
            return NotFound("Show not found");

        show.Seen = seen;
        
        foreach (Season season in show.Seasons)
        {
            season.Seen = seen;
            foreach (Episode episode in season.Episodes)
            {
                episode.Seen = seen;
            }
        }
        
        MediaList? seenList = await _context.MediaLists
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.IsSystem && ml.Name == "Seen");

        if (seenList != null)
        {
            if (seen && !seenList.Shows.Any(s => s.Id == show.Id))
            {
                seenList.Shows.Add(show);
            }
            else if (!seen)
            {
                seenList.Shows.Remove(show);
            }
        }

        await _context.SaveChangesAsync();
        return show;
    }

    [HttpPost("seasons/{id}/seen")]
    public async Task<ActionResult<ModelsDTO.SeasonDto>> MarkSeasonAsSeen(int id, [FromBody] bool seen = true)
    {
        Season? season = await _context.Seasons
            .Include(s => s.Episodes)
            .Include(s => s.Show)
            .FirstOrDefaultAsync(s => s.Id == id);

        if (season == null)
            return NotFound("Season not found");

        season.Seen = seen;
        
        foreach (Episode episode in season.Episodes)
        {
            episode.Seen = seen;
        }
        
        MediaList? seenList = await _context.MediaLists
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.IsSystem && ml.Name == "Seen");

        if (seenList != null && seen)
        {
            if (!seenList.Shows.Any(s => s.Id == season.ShowId))
            {
                seenList.Shows.Add(season.Show);
            }
        }

        await _context.SaveChangesAsync();
        return season.ToDto();
    }

    [HttpPost("episodes/{id}/seen")]
    public async Task<ActionResult<ModelsDTO.EpisodeDto>> MarkEpisodeAsSeen(int id, [FromBody] bool seen = true)
    {
        Episode? episode = await _context.Episodes
            .Include(e => e.Season)
                .ThenInclude(s => s.Show)
            .FirstOrDefaultAsync(e => e.Id == id);
            
        if (episode == null)
            return NotFound("Episode not found");

        episode.Seen = seen;
        
        MediaList? seenList = await _context.MediaLists
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.IsSystem && ml.Name == "Seen");

        if (seenList != null && seen)
        {
            Show show = episode.Season.Show;
            if (!seenList.Shows.Any(s => s.Id == show.Id))
            {
                seenList.Shows.Add(show);
            }
        }
        
        await _context.SaveChangesAsync();
        return episode.ToDto();
    }

    [HttpPost("{tmdbId}/refresh")]
    public async Task<ActionResult<ShowDto>> RefreshShow(int tmdbId)
    {
        Show? show = await _context.Shows
            .Include(s => s.Seasons)
                .ThenInclude(s => s.Episodes)
            .Include(s => s.MediaLists)
            .FirstOrDefaultAsync(s => s.TmdbId == tmdbId);

        if (show == null)
            return NotFound("Show not found in database");

        // Fetch fresh data from TMDb
        TMDbShowResponse? tmdbShow = await _tmdbService.GetShowAsync(tmdbId);
        if (tmdbShow == null)
            return NotFound("Show not found on TMDb");

        List<TMDbSeasonSummary> regularSeasons = tmdbShow.Seasons
            .Where(s => s.SeasonNumber > 0)
            .ToList();

        // Update show fields
        show.Title = tmdbShow.Name;
        show.OriginalTitle = tmdbShow.OriginalName;
        show.Overview = tmdbShow.Overview;
        show.Status = tmdbShow.Status;
        show.Tagline = tmdbShow.Tagline;
        show.PosterPath = tmdbShow.PosterPath;
        show.BackdropPath = tmdbShow.BackdropPath;
        show.VoteAverage = tmdbShow.VoteAverage;
        show.VoteCount = tmdbShow.VoteCount;
        show.Popularity = tmdbShow.Popularity;
        show.ReleaseDate = ParseDate(tmdbShow.FirstAirDate);
        show.LastAirDate = ParseDate(tmdbShow.LastAirDate);
        show.Genres = string.Join(", ", tmdbShow.Genres.Select(g => g.Name));
        show.LastUpdated = DateTime.UtcNow;

        // Refresh seasons and episodes
        int totalEpisodeCount = 0;
        foreach (TMDbSeasonSummary seasonSummary in regularSeasons)
        {
            TMDbSeasonResponse? tmdbSeason = await _tmdbService.GetSeasonAsync(tmdbId, seasonSummary.SeasonNumber);
            if (tmdbSeason == null) continue;

            Season? existingSeason = show.Seasons.FirstOrDefault(s => s.SeasonNumber == tmdbSeason.SeasonNumber);
            if (existingSeason == null)
            {
                existingSeason = new Season
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
                _context.Seasons.Add(existingSeason);
                await _context.SaveChangesAsync();
            }
            else
            {
                existingSeason.TmdbId = tmdbSeason.Id;
                existingSeason.Name = tmdbSeason.Name;
                existingSeason.Overview = tmdbSeason.Overview;
                existingSeason.EpisodeCount = tmdbSeason.Episodes.Count;
                existingSeason.AirDate = ParseDate(tmdbSeason.AirDate);
                existingSeason.PosterPath = tmdbSeason.PosterPath;
            }

            foreach (TMDbEpisodeResponse tmdbEpisode in tmdbSeason.Episodes)
            {
                Episode? existingEpisode = existingSeason.Episodes?.FirstOrDefault(e => e.EpisodeNumber == tmdbEpisode.EpisodeNumber);
                if (existingEpisode == null)
                {
                    Episode newEpisode = new Episode
                    {
                        TmdbId = tmdbEpisode.Id,
                        Name = tmdbEpisode.Name,
                        Overview = tmdbEpisode.Overview,
                        EpisodeNumber = tmdbEpisode.EpisodeNumber,
                        Runtime = tmdbEpisode.Runtime ?? 0,
                        VoteAverage = tmdbEpisode.VoteAverage,
                        AirDate = ParseDate(tmdbEpisode.AirDate),
                        StillPath = tmdbEpisode.StillPath,
                        SeasonId = existingSeason.Id
                    };
                    _context.Episodes.Add(newEpisode);
                }
                else
                {
                    existingEpisode.TmdbId = tmdbEpisode.Id;
                    existingEpisode.Name = tmdbEpisode.Name;
                    existingEpisode.Overview = tmdbEpisode.Overview;
                    existingEpisode.Runtime = tmdbEpisode.Runtime ?? 0;
                    existingEpisode.VoteAverage = tmdbEpisode.VoteAverage;
                    existingEpisode.AirDate = ParseDate(tmdbEpisode.AirDate);
                    existingEpisode.StillPath = tmdbEpisode.StillPath;
                }
            }

            totalEpisodeCount += tmdbSeason.Episodes.Count;
        }

        show.NumberOfSeasons = regularSeasons.Count;
        show.NumberOfEpisodes = totalEpisodeCount;

        // Refresh OMDb ratings
        string queryTitle = string.IsNullOrWhiteSpace(show.OriginalTitle) ? show.Title : show.OriginalTitle!;
        OmdbRatingsResult result = await _omdbService.GetExternalRatingsAsync(null, queryTitle, show.ReleaseDate?.Year);
        if (result.Ratings != null)
        {
            show.ImdbRating = result.Ratings.ImdbRating;
            show.ImdbVotes = result.Ratings.ImdbVotes;
            show.RottenTomatoesRating = result.Ratings.RottenTomatoesRating;
        }

        await _context.SaveChangesAsync();

        // Reload with updated data
        show = await _context.Shows
            .Include(s => s.Seasons)
                .ThenInclude(s => s.Episodes)
            .Include(s => s.MediaLists)
            .FirstAsync(s => s.Id == show.Id);

        return MapToDto(show);
    }

    private static DateTime? ParseDate(string? dateString)
    {
        if (string.IsNullOrEmpty(dateString))
            return null;
        return DateTime.TryParse(dateString, out DateTime date) ? date : null;
    }

    private static ShowDto MapToDto(Show show, DateTime? listAddedAt = null)
    {
        return new ShowDto
        {
            Id = show.Id,
            TmdbId = show.TmdbId,
            Title = show.Title,
            OriginalTitle = show.OriginalTitle,
            Overview = show.Overview,
            Status = show.Status,
            Tagline = show.Tagline,
            PosterPath = show.PosterPath,
            BackdropPath = show.BackdropPath,
            VoteAverage = show.VoteAverage,
            VoteCount = show.VoteCount,
            Popularity = show.Popularity,
            Liked = show.Liked,
            Seen = show.Seen,
            ReleaseDate = show.ReleaseDate,
            Genres = show.Genres,
            AddedAt = show.AddedAt,
            LastUpdated = show.LastUpdated,
            Ratings = show.ToRatings().ToDto(),
            NumberOfSeasons = show.Seasons.Count(s => s.SeasonNumber > 0),
            NumberOfEpisodes = show.Seasons
                .Where(s => s.SeasonNumber > 0)
                .Sum(s => s.Episodes?.Count ?? 0),
            LastAirDate = show.LastAirDate,
            Seasons = show.Seasons
                .Where(s => s.SeasonNumber > 0)
                .ToList(),
            ListIds = show.MediaLists.Select(ml => ml.Id).ToList(),
            ListAddedAt = listAddedAt
        };
    }

    [HttpGet("{tmdbId}/ratings")]
    public async Task<ActionResult<MediaRatingsDto?>> GetRatings(int tmdbId)
    {
        Show? show = await _context.Shows.FirstOrDefaultAsync(s => s.TmdbId == tmdbId);
        if (show == null)
        {
            return NotFound("Show not found");
        }

        if (HasStoredExternalRatings(show))
        {
            return show.ToRatings().ToDto();
        }

        string queryTitle = string.IsNullOrWhiteSpace(show.OriginalTitle) ? show.Title : show.OriginalTitle!;
        int? releaseYear = show.ReleaseDate?.Year;
        OmdbRatingsResult result = await _omdbService.GetExternalRatingsAsync(null, queryTitle, releaseYear);
        if (result.Ratings == null)
        {
            return NoContent();
        }

        show.ImdbRating = result.Ratings.ImdbRating;
        show.ImdbVotes = result.Ratings.ImdbVotes;
        show.RottenTomatoesRating = result.Ratings.RottenTomatoesRating;
        await _context.SaveChangesAsync();

        return show.ToRatings().ToDto();
    }

    private static bool HasStoredExternalRatings(Show show)
    {
        return show.ImdbRating.HasValue || show.ImdbVotes.HasValue || show.RottenTomatoesRating.HasValue;
    }
}
