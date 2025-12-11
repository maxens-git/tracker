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
public class MediaListsController : ControllerBase
{
    private readonly ApiDbContext _context;
    private readonly TMDbService _tmdbService;
    private const int PageSize = 20;

    public MediaListsController(ApiDbContext context, TMDbService tmdbService)
    {
        _context = context;
        _tmdbService = tmdbService;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<MediaListSummaryDto>>> GetAll()
    {
        List<MediaListSummaryDto> lists = await _context.MediaLists
            .Select(ml => new MediaListSummaryDto
            {
                Id = ml.Id,
                Name = ml.Name,
                Description = ml.Description,
                Icon = ml.Icon,
                IsSystem = ml.IsSystem,
                MoviesCount = ml.Movies.Count,
                ShowsCount = ml.Shows.Count,
                CreatedAt = ml.CreatedAt,
                UpdatedAt = ml.UpdatedAt
            })
            .ToListAsync();

        return lists;
    }

    [HttpGet("watchlist/movies")]
    public async Task<ActionResult<PaginatedResult<ModelsDTO.MovieDto>>> GetWatchlistMovies([FromQuery] int page = 1)
    {
        IQueryable<MediaListMovie> query = _context.MediaListMovies
            .Include(x => x.Movie)
            .ThenInclude(m => m.MediaLists)
            .Where(x => x.MediaList.IsSystem && x.MediaList.Name == "Watchlist")
            .OrderByDescending(x => x.AddedAt);

        int totalCount = await query.CountAsync();

        List<MediaListMovie> movies = await query
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<ModelsDTO.MovieDto>
        {
            Items = movies.Select(m => m.Movie.ToDto(m.AddedAt)).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpGet("watchlist/shows")]
    public async Task<ActionResult<PaginatedResult<ModelsDTO.ShowDto>>> GetWatchlistShows([FromQuery] int page = 1)
    {
        IQueryable<MediaListShow> query = _context.MediaListShows
            .Include(x => x.Show)
            .ThenInclude(s => s.MediaLists)
            .Where(x => x.MediaList.IsSystem && x.MediaList.Name == "Watchlist")
            .OrderByDescending(x => x.AddedAt);

        int totalCount = await query.CountAsync();

        List<MediaListShow> shows = await query
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<ModelsDTO.ShowDto>
        {
            Items = shows.Select(s => s.Show.ToDto(s.AddedAt)).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpGet("liked/movies")]
    public async Task<ActionResult<PaginatedResult<ModelsDTO.MovieDto>>> GetLikedMovies([FromQuery] int page = 1)
    {
        int totalCount = await _context.Movies.CountAsync(m => m.Liked);

        List<Movie> movies = await _context.Movies
            .Where(m => m.Liked)
            .Include(m => m.MediaLists)
            .OrderByDescending(m => m.LastUpdated)
            .ThenByDescending(m => m.Id)
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<ModelsDTO.MovieDto>
        {
            Items = movies.Select(m => m.ToDto()).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpGet("liked/shows")]
    public async Task<ActionResult<PaginatedResult<ModelsDTO.ShowDto>>> GetLikedShows([FromQuery] int page = 1)
    {
        int totalCount = await _context.Shows.CountAsync(s => s.Liked);

        List<Show> shows = await _context.Shows
            .Where(s => s.Liked)
            .Include(s => s.MediaLists)
            .OrderByDescending(s => s.LastUpdated)
            .ThenByDescending(s => s.Id)
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<ModelsDTO.ShowDto>
        {
            Items = shows.Select(s => s.ToDto()).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpGet("seen/movies")]
    public async Task<ActionResult<PaginatedResult<ModelsDTO.MovieDto>>> GetSeenMovies([FromQuery] int page = 1)
    {
        int totalCount = await _context.Movies.CountAsync(m => m.Seen);

        List<Movie> movies = await _context.Movies
            .Where(m => m.Seen)
            .Include(m => m.MediaLists)
            .OrderByDescending(m => m.LastUpdated)
            .ThenByDescending(m => m.Id)
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<ModelsDTO.MovieDto>
        {
            Items = movies.Select(m => m.ToDto()).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpGet("seen/shows")]
    public async Task<ActionResult<PaginatedResult<ModelsDTO.ShowDto>>> GetSeenShows([FromQuery] int page = 1)
    {
        int totalCount = await _context.Shows.CountAsync(s => s.Seen);

        List<Show> shows = await _context.Shows
            .Where(s => s.Seen)
            .Include(s => s.MediaLists)
            .OrderByDescending(s => s.LastUpdated)
            .ThenByDescending(s => s.Id)
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<ModelsDTO.ShowDto>
        {
            Items = shows.Select(s => s.ToDto()).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<MediaListSummaryDto>> GetById(int id)
    {
        MediaListSummaryDto? mediaList = await _context.MediaLists
            .Where(ml => ml.Id == id)
            .Select(ml => new MediaListSummaryDto
            {
                Id = ml.Id,
                Name = ml.Name,
                Description = ml.Description,
                Icon = ml.Icon,
                IsSystem = ml.IsSystem,
                MoviesCount = ml.Movies.Count,
                ShowsCount = ml.Shows.Count,
                CreatedAt = ml.CreatedAt,
                UpdatedAt = ml.UpdatedAt
            })
            .FirstOrDefaultAsync();

        if (mediaList == null)
            return NotFound();

        return mediaList;
    }

    [HttpGet("{id}/movies")]
    public async Task<ActionResult<PaginatedResult<ModelsDTO.MovieDto>>> GetMovies(int id, [FromQuery] int page = 1)
    {
        bool exists = await _context.MediaLists.AnyAsync(ml => ml.Id == id);
        if (!exists)
            return NotFound("List not found");

        IQueryable<MediaListMovie> query = _context.MediaListMovies
            .Include(x => x.Movie)
            .ThenInclude(m => m.MediaLists)
            .Where(x => x.MediaListId == id)
            .OrderByDescending(x => x.AddedAt);

        int totalCount = await query.CountAsync();

        List<MediaListMovie> movies = await query
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<ModelsDTO.MovieDto>
        {
            Items = movies.Select(m => m.Movie.ToDto(m.AddedAt)).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpGet("{id}/shows")]
    public async Task<ActionResult<PaginatedResult<ModelsDTO.ShowDto>>> GetShows(int id, [FromQuery] int page = 1)
    {
        bool exists = await _context.MediaLists.AnyAsync(ml => ml.Id == id);
        if (!exists)
            return NotFound("List not found");

        IQueryable<MediaListShow> query = _context.MediaListShows
            .Include(x => x.Show)
            .ThenInclude(s => s.MediaLists)
            .Where(x => x.MediaListId == id)
            .OrderByDescending(x => x.AddedAt);

        int totalCount = await query.CountAsync();

        List<MediaListShow> shows = await query
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<ModelsDTO.ShowDto>
        {
            Items = shows.Select(s => s.Show.ToDto(s.AddedAt)).ToList(),
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpGet("{id}/search")]
    public async Task<ActionResult<PaginatedResult<MediaListSearchItemDto>>> SearchListItems(
        int id,
        [FromQuery] string query = "",
        [FromQuery] int page = 1,
        [FromQuery] string type = "all")
    {
        if (string.IsNullOrWhiteSpace(query))
            return BadRequest("Query cannot be empty");

        MediaList? mediaList = await _context.MediaLists.FirstOrDefaultAsync(ml => ml.Id == id);
        if (mediaList == null)
            return NotFound("List not found");

        string normalized = query.Trim().ToLower();

        IQueryable<MediaListSearchItemDto> movieQuery = _context.MediaListMovies
            .Where(x => x.MediaListId == id && x.Movie.Title.ToLower().Contains(normalized))
            .Select(m => new MediaListSearchItemDto
            {
                Id = m.MovieId,
                TmdbId = m.Movie.TmdbId,
                Title = m.Movie.Title,
                PosterPath = m.Movie.PosterPath,
                ReleaseDate = m.Movie.ReleaseDate,
                VoteAverage = m.Movie.VoteAverage,
                Popularity = m.Movie.Popularity,
                LastUpdated = m.Movie.LastUpdated,
                AddedAt = m.AddedAt,
                MediaType = "movie"
            });

        IQueryable<MediaListSearchItemDto> showQuery = _context.MediaListShows
            .Where(x => x.MediaListId == id && x.Show.Title.ToLower().Contains(normalized))
            .Select(s => new MediaListSearchItemDto
            {
                Id = s.ShowId,
                TmdbId = s.Show.TmdbId,
                Title = s.Show.Title,
                PosterPath = s.Show.PosterPath,
                ReleaseDate = s.Show.ReleaseDate,
                VoteAverage = s.Show.VoteAverage,
                Popularity = s.Show.Popularity,
                LastUpdated = s.Show.LastUpdated,
                AddedAt = s.AddedAt,
                MediaType = "show"
            });

        IQueryable<MediaListSearchItemDto> combinedQuery = type.ToLower() switch
        {
            "movie" => movieQuery,
            "show" => showQuery,
            _ => movieQuery.Concat(showQuery)
        };

        int totalCount = await combinedQuery.CountAsync();

        List<MediaListSearchItemDto> items = await combinedQuery
            .OrderByDescending(i => i.AddedAt ?? DateTime.MinValue)
            .ThenByDescending(i => i.Popularity ?? 0)
            .ThenByDescending(i => i.VoteAverage ?? 0)
            .Skip((page - 1) * PageSize)
            .Take(PageSize)
            .ToListAsync();

        return new PaginatedResult<MediaListSearchItemDto>
        {
            Items = items,
            Page = page,
            PageSize = PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)PageSize)
        };
    }

    [HttpPost]
    public async Task<ActionResult<MediaList>> Create(MediaListCreateDto dto)
    {
        MediaList mediaList = new MediaList
        {
            Name = dto.Name,
            Description = dto.Description,
            Icon = dto.Icon
        };

        _context.MediaLists.Add(mediaList);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = mediaList.Id }, mediaList);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, MediaListUpdateDto dto)
    {
        MediaList? mediaList = await _context.MediaLists.FindAsync(id);

        if (mediaList == null)
            return NotFound();

        if (mediaList.IsSystem)
            return BadRequest("Cannot modify system list");

        mediaList.Name = dto.Name ?? mediaList.Name;
        mediaList.Description = dto.Description ?? mediaList.Description;
        mediaList.Icon = dto.Icon ?? mediaList.Icon;
        mediaList.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        MediaList? mediaList = await _context.MediaLists.FindAsync(id);

        if (mediaList == null)
            return NotFound();

        if (mediaList.IsSystem)
            return BadRequest("Cannot delete system list");

        _context.MediaLists.Remove(mediaList);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpPost("{id}/movies/{tmdbId}")]
    public async Task<IActionResult> AddMovie(int id, int tmdbId)
    {
        MediaList? mediaList = await _context.MediaLists
            .Include(ml => ml.Movies)
            .FirstOrDefaultAsync(ml => ml.Id == id);

        if (mediaList == null)
            return NotFound("List not found");

        Movie? movie = await _context.Movies.FirstOrDefaultAsync(m => m.TmdbId == tmdbId);

        if (movie == null)
        {
            TMDbMovieResponse? tmdbMovie = await _tmdbService.GetMovieAsync(tmdbId);
            if (tmdbMovie == null)
                return NotFound("Movie not found on TMDb");

            movie = new Movie
            {
                TmdbId = tmdbMovie.Id,
                Title = tmdbMovie.Title,
                OriginalTitle = tmdbMovie.OriginalTitle,
                Overview = tmdbMovie.Overview,
                Status = tmdbMovie.Status,
                Tagline = tmdbMovie.Tagline,
                PosterPath = tmdbMovie.PosterPath,
                BackdropPath = tmdbMovie.BackdropPath,
                VoteAverage = tmdbMovie.VoteAverage,
                VoteCount = tmdbMovie.VoteCount,
                Popularity = tmdbMovie.Popularity,
                ReleaseDate = ParseDate(tmdbMovie.ReleaseDate),
                Runtime = tmdbMovie.Runtime,
                Budget = tmdbMovie.Budget,
                Revenue = tmdbMovie.Revenue,
                ImdbId = tmdbMovie.ImdbId,
                Genres = string.Join(", ", tmdbMovie.Genres.Select(g => g.Name))
            };

            _context.Movies.Add(movie);
        }

        if (mediaList.Movies.Any(m => m.TmdbId == tmdbId))
            return BadRequest("Movie already in list");

        mediaList.Movies.Add(movie);
        mediaList.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id}/movies/{tmdbId}")]
    public async Task<IActionResult> RemoveMovie(int id, int tmdbId)
    {
        MediaList? mediaList = await _context.MediaLists
            .Include(ml => ml.Movies)
            .FirstOrDefaultAsync(ml => ml.Id == id);

        if (mediaList == null)
            return NotFound("List not found");

        Movie? movie = mediaList.Movies.FirstOrDefault(m => m.TmdbId == tmdbId);
        if (movie == null)
            return NotFound("Movie not in list");

        mediaList.Movies.Remove(movie);
        mediaList.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpPost("{id}/shows/{tmdbId}")]
    public async Task<IActionResult> AddShow(int id, int tmdbId)
    {
        MediaList? mediaList = await _context.MediaLists
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.Id == id);

        if (mediaList == null)
            return NotFound("List not found");

        Show? show = await _context.Shows.FirstOrDefaultAsync(s => s.TmdbId == tmdbId);

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
        }

        if (mediaList.Shows.Any(s => s.TmdbId == tmdbId))
            return BadRequest("Show already in list");

        mediaList.Shows.Add(show);
        mediaList.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id}/shows/{tmdbId}")]
    public async Task<IActionResult> RemoveShow(int id, int tmdbId)
    {
        MediaList? mediaList = await _context.MediaLists
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.Id == id);

        if (mediaList == null)
            return NotFound("List not found");

        Show? show = mediaList.Shows.FirstOrDefault(s => s.TmdbId == tmdbId);
        if (show == null)
            return NotFound("Show not in list");

        mediaList.Shows.Remove(show);
        mediaList.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpPost("movies/{tmdbId}/like")]
    public async Task<IActionResult> LikeMovie(int tmdbId, [FromQuery] bool liked = true)
    {
        Movie? movie = await EnsureMovieExists(tmdbId);

        if (movie == null)
            return NotFound("Movie not found on TMDb");

        movie.Liked = liked;
        movie.LastUpdated = DateTime.UtcNow;

        MediaList? likesList = await _context.MediaLists
            .Include(ml => ml.Movies)
            .FirstOrDefaultAsync(ml => ml.IsSystem && ml.Name == "J'aime");
        if (likesList != null)
        {
            if (liked)
            {
                if (!likesList.Movies.Any(m => m.TmdbId == tmdbId))
                    likesList.Movies.Add(movie);
            }
            else
            {
                Movie? existing = likesList.Movies.FirstOrDefault(m => m.TmdbId == tmdbId);
                if (existing != null)
                    likesList.Movies.Remove(existing);
            }

            likesList.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();

        return Ok(new { movie.TmdbId, movie.Liked });
    }

    [HttpPost("shows/{tmdbId}/like")]
    public async Task<IActionResult> LikeShow(int tmdbId, [FromQuery] bool liked = true)
    {
        Show? show = await EnsureShowExists(tmdbId);

        if (show == null)
            return NotFound("Show not found on TMDb");

        show.Liked = liked;
        show.LastUpdated = DateTime.UtcNow;

        MediaList? likesList = await _context.MediaLists
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.IsSystem && ml.Name == "J'aime");
        if (likesList != null)
        {
            if (liked)
            {
                if (!likesList.Shows.Any(s => s.TmdbId == tmdbId))
                    likesList.Shows.Add(show);
            }
            else
            {
                Show? existing = likesList.Shows.FirstOrDefault(s => s.TmdbId == tmdbId);
                if (existing != null)
                    likesList.Shows.Remove(existing);
            }

            likesList.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();

        return Ok(new { show.TmdbId, show.Liked });
    }

    private static DateTime? ParseDate(string? dateString)
    {
        if (string.IsNullOrEmpty(dateString))
            return null;
        return DateTime.TryParse(dateString, out DateTime date) ? date : null;
    }

    private async Task<Movie?> EnsureMovieExists(int tmdbId)
    {
        Movie? movie = await _context.Movies.FirstOrDefaultAsync(m => m.TmdbId == tmdbId);
        if (movie != null)
            return movie;

        TMDbMovieResponse? tmdbMovie = await _tmdbService.GetMovieAsync(tmdbId);
        if (tmdbMovie == null)
            return null;

        movie = new Movie
        {
            TmdbId = tmdbMovie.Id,
            Title = tmdbMovie.Title,
            OriginalTitle = tmdbMovie.OriginalTitle,
            Overview = tmdbMovie.Overview,
            Status = tmdbMovie.Status,
            Tagline = tmdbMovie.Tagline,
            PosterPath = tmdbMovie.PosterPath,
            BackdropPath = tmdbMovie.BackdropPath,
            VoteAverage = tmdbMovie.VoteAverage,
            VoteCount = tmdbMovie.VoteCount,
            Popularity = tmdbMovie.Popularity,
            ReleaseDate = ParseDate(tmdbMovie.ReleaseDate),
            Runtime = tmdbMovie.Runtime,
            Budget = tmdbMovie.Budget,
            Revenue = tmdbMovie.Revenue,
            ImdbId = tmdbMovie.ImdbId,
            Genres = string.Join(", ", tmdbMovie.Genres.Select(g => g.Name))
        };

        _context.Movies.Add(movie);
        await _context.SaveChangesAsync();

        return movie;
    }

    private async Task<Show?> EnsureShowExists(int tmdbId)
    {
        Show? show = await _context.Shows.FirstOrDefaultAsync(s => s.TmdbId == tmdbId);
        if (show != null)
            return show;

        TMDbShowResponse? tmdbShow = await _tmdbService.GetShowAsync(tmdbId);
        if (tmdbShow == null)
            return null;

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

        return show;
    }

}
