using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tracker.Data;
using Tracker.Models;
using Tracker.Models.JustWatch;
using Tracker.Models.TMDbResponses;
using Tracker.Services;

public static class DbInitializer
{
    public static async Task InitializeAsync(ApiDbContext context, TMDbService tmdbService, ILogger logger, string? exportFilePath = null)
    {
        await context.Database.MigrateAsync();

        string resolvedExportPath = exportFilePath ?? string.Empty;
        if (string.IsNullOrEmpty(resolvedExportPath))
        {
            resolvedExportPath = Path.Combine(AppContext.BaseDirectory, "Seed", "Data", "export_justwatch.json");
        }
        else if (!Path.IsPathRooted(resolvedExportPath))
        {
            resolvedExportPath = Path.Combine(AppContext.BaseDirectory, resolvedExportPath);
        }

        string logDirectory = Path.GetDirectoryName(resolvedExportPath) ?? Path.Combine(AppContext.BaseDirectory, "Seed", "Data");
        string errorLogPath = Path.Combine(logDirectory, "import_errors.log");

        await ImportMediaAsync(context, tmdbService, logger, resolvedExportPath, errorLogPath);
        await CreateOrUpdateSystemListsAsync(context, logger);

        logger.LogInformation("Import terminé");
    }

    private static async Task ImportMediaAsync(ApiDbContext context, TMDbService tmdbService, ILogger logger, string exportFilePath, string errorLogPath)
    {
        if (!File.Exists(exportFilePath))
        {
            logger.LogWarning("Fichier export JustWatch non trouvé: {Path}", exportFilePath);
            await AppendImportErrorAsync(errorLogPath, "File", null, null, $"Export introuvable: {exportFilePath}");
            return;
        }

        string jsonContent = await File.ReadAllTextAsync(exportFilePath);
        List<JustWatchItem>? items = JsonSerializer.Deserialize<List<JustWatchItem>>(jsonContent);

        if (items == null || items.Count == 0)
        {
            logger.LogWarning("Aucun élément trouvé dans le fichier export");
            await AppendImportErrorAsync(errorLogPath, "File", null, null, "Fichier export vide ou invalide");
            return;
        }

        logger.LogInformation("Import de {Count} éléments depuis JustWatch", items.Count);

        foreach (JustWatchItem item in items)
        {
            if (!string.IsNullOrEmpty(item.TmdbId) && int.TryParse(item.TmdbId, out int tmdbId))
            {
                try
                {
                    if (item.IsMovie)
                    {
                        await ImportMovieAsync(context, tmdbService, tmdbId, logger, item.ImdbId, errorLogPath);
                    }
                    else if (item.IsShow)
                    {
                        await ImportShowAsync(context, tmdbService, tmdbId, logger, errorLogPath);
                    }
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Erreur lors de l'import de {Title} (TMDb: {TmdbId})", item.Title, tmdbId);
                    await AppendImportErrorAsync(errorLogPath, item.IsMovie ? "Movie" : item.IsShow ? "Show" : "Unknown", tmdbId, item.Title, ex.Message);
                    if (ex is InvalidOperationException)
                    {
                        throw;
                    }
                }
            }
            else
            {
                logger.LogWarning("TmdbId invalide pour {Title}", item.Title);
                await AppendImportErrorAsync(errorLogPath, item.IsMovie ? "Movie" : item.IsShow ? "Show" : "Unknown", null, item.Title, "TmdbId invalide");
            }
        }
    }

    private static async Task CreateOrUpdateSystemListsAsync(ApiDbContext context, ILogger logger)
    {
        List<Movie> seenMovies = await context.Movies.Where(m => m.Seen).ToListAsync();
        List<Show> seenShows = await context.Shows.Where(s => s.Seen).ToListAsync();

        MediaList? seenList = await context.MediaLists
            .Include(ml => ml.Movies)
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.IsSystem && ml.Name == "Seen");

        if (seenList == null)
        {
            seenList = new MediaList
            {
                Name = "Seen",
                Description = "Titre vus",
                Icon = "",
                IsSystem = true,
                Movies = seenMovies,
                Shows = seenShows
            };

            context.MediaLists.Add(seenList);
        }
        else
        {
            foreach (Movie movie in seenMovies)
            {
                if (!seenList.Movies.Any(m => m.Id == movie.Id))
                {
                    seenList.Movies.Add(movie);
                }
            }

            foreach (Show show in seenShows)
            {
                if (!seenList.Shows.Any(s => s.Id == show.Id))
                {
                    seenList.Shows.Add(show);
                }
            }

            context.MediaLists.Update(seenList);
        }

        List<Movie> likedMovies = await context.Movies.Where(m => m.Liked).ToListAsync();
        List<Show> likedShows = await context.Shows.Where(s => s.Liked).ToListAsync();

        MediaList? likesList = await context.MediaLists
            .Include(ml => ml.Movies)
            .Include(ml => ml.Shows)
            .FirstOrDefaultAsync(ml => ml.IsSystem && ml.Name == "J'aime");

        if (likesList == null)
        {
            likesList = new MediaList
            {
                Name = "J'aime",
                Description = "Titres que vous aimez",
                Icon = "❤",
                IsSystem = true,
                Movies = likedMovies,
                Shows = likedShows
            };

            context.MediaLists.Add(likesList);
        }
        else
        {
            foreach (Movie movie in likedMovies)
            {
                if (!likesList.Movies.Any(m => m.Id == movie.Id))
                {
                    likesList.Movies.Add(movie);
                }
            }

            foreach (Show show in likedShows)
            {
                if (!likesList.Shows.Any(s => s.Id == show.Id))
                {
                    likesList.Shows.Add(show);
                }
            }

            context.MediaLists.Update(likesList);
        }

        if (!await context.MediaLists.AnyAsync(ml => ml.IsSystem && ml.Name == "Watchlist"))
        {
            MediaList watchlist = new MediaList
            {
                Name = "Watchlist",
                Description = "Titres à voir prochainement",
                Icon = "📌",
                IsSystem = true,
                Movies = new List<Movie>(),
                Shows = new List<Show>()
            };

            context.MediaLists.Add(watchlist);
        }

        await context.SaveChangesAsync();
    }

    private static async Task<Movie?> ImportMovieAsync(ApiDbContext context, TMDbService tmdbService, int tmdbId, ILogger logger, string? imdbId, string errorLogPath)
    {
        Movie? m = await context.Movies.FirstOrDefaultAsync(m => m.TmdbId == tmdbId);
        if (m != null)
        {
            m.Seen = true;
            context.Movies.Update(m);
            await context.SaveChangesAsync();
            logger.LogDebug("Film déjà existant: TMDb {TmdbId}", tmdbId);
            return m;
        }

        TMDbMovieResponse? tmdbMovie = await tmdbService.GetMovieAsync(tmdbId);
        if (tmdbMovie == null)
        {
            logger.LogWarning("Film non trouvé sur TMDb: {TmdbId}", tmdbId);
            await AppendImportErrorAsync(errorLogPath, "Movie", tmdbId, imdbId, "Film introuvable sur TMDb");
            return null;
        }

        Movie movie = new Movie
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
            Genres = string.Join(", ", tmdbMovie.Genres.Select(g => g.Name)),
            Seen = true
        };

        if (!string.IsNullOrEmpty(imdbId) && movie.ImdbId != imdbId)
        {
            logger.LogError("IMDbId incohérent pour {Title}: attendu {Expected}, obtenu {Actual}", movie.Title, imdbId, movie.ImdbId);
            await AppendImportErrorAsync(errorLogPath, "Movie", tmdbId, movie.Title, $"IMDbId attendu {imdbId}, obtenu {movie.ImdbId}");
        }

        context.Movies.Add(movie);
        await context.SaveChangesAsync();
        logger.LogInformation("Film ajouté: {Title}", movie.Title);
        return movie;
    }

    private static async Task ImportShowAsync(ApiDbContext context, TMDbService tmdbService, int tmdbId, ILogger logger, string errorLogPath)
    {
        Show? db = await context.Shows
            .Include(s => s.Seasons)
            .ThenInclude(s => s.Episodes)
            .FirstOrDefaultAsync(s => s.TmdbId == tmdbId);
        if (db != null)
        {
            db.Seen = true;
            foreach (Season s in db.Seasons)
            {
                s.Seen = true;
                foreach (Episode e in s.Episodes)
                {
                    e.Seen = true;
                }
            }
            context.Shows.Update(db);
            await context.SaveChangesAsync();
            logger.LogDebug("Série déjà existante: TMDb {TmdbId}", tmdbId);
            return;
        }

        TMDbShowResponse? tmdbShow = await tmdbService.GetShowAsync(tmdbId);
        if (tmdbShow == null)
        {
            logger.LogWarning("Série non trouvée sur TMDb: {TmdbId}", tmdbId);
            await AppendImportErrorAsync(errorLogPath, "Show", tmdbId, null, "Série introuvable sur TMDb");
            return;
        }

        Show show = new Show
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
            Genres = string.Join(", ", tmdbShow.Genres.Select(g => g.Name)),
            Seen = true
        };

        context.Shows.Add(show);
        await context.SaveChangesAsync();

        foreach (TMDbSeasonSummary seasonSummary in tmdbShow.Seasons)
        {
            TMDbSeasonResponse? tmdbSeason = await tmdbService.GetSeasonAsync(tmdbId, seasonSummary.SeasonNumber);
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
                ShowId = show.Id,
                Seen = true
            };

            context.Seasons.Add(season);
            await context.SaveChangesAsync();

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
                    SeasonId = season.Id,
                    Seen = true
                };

                context.Episodes.Add(episode);
            }

            await context.SaveChangesAsync();
        }

        logger.LogInformation("Série ajoutée: {Title} ({Seasons} saisons)", show.Title, show.NumberOfSeasons);
    }

    private static DateTime? ParseDate(string? dateString)
    {
        if (string.IsNullOrEmpty(dateString))
            return null;

        if (DateTime.TryParse(dateString, out var date))
            return date;

        return null;
    }

    private static async Task AppendImportErrorAsync(string logPath, string kind, int? tmdbId, string? title, string message)
    {
        string? directory = Path.GetDirectoryName(logPath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        string line = $"{DateTime.UtcNow:O}\t{kind}\tTMDb:{tmdbId?.ToString() ?? "N/A"}\tTitle:{title ?? "N/A"}\t{message}";
        await File.AppendAllTextAsync(logPath, line + Environment.NewLine);
    }
}