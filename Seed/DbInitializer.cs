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

        if (string.IsNullOrEmpty(exportFilePath))
        {
            exportFilePath = Path.Combine(AppContext.BaseDirectory, "Seed", "Data", "export_justwatch.json");
        }
        else if (!Path.IsPathRooted(exportFilePath))
        {
            exportFilePath = Path.Combine(AppContext.BaseDirectory, exportFilePath);
        }

        if (!File.Exists(exportFilePath))
        {
            logger.LogWarning("Fichier export JustWatch non trouvé: {Path}", exportFilePath);
            return;
        }

        string jsonContent = await File.ReadAllTextAsync(exportFilePath);
        List<JustWatchItem>? items = JsonSerializer.Deserialize<List<JustWatchItem>>(jsonContent);

        if (items == null || items.Count == 0)
        {
            logger.LogWarning("Aucun élément trouvé dans le fichier export");
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
                        await ImportMovieAsync(context, tmdbService, tmdbId, logger);
                    }
                    else if (item.IsShow)
                    {
                        await ImportShowAsync(context, tmdbService, tmdbId, logger);
                    }
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Erreur lors de l'import de {Title} (TMDb: {TmdbId})", item.Title, tmdbId);
                }
            } 
            else 
            {
                logger.LogWarning("TmdbId invalide pour {Title}", item.Title);
            }
        }

        List<Movie> movies = await context.Movies.ToListAsync();
        List<Show> shows = await context.Shows.ToListAsync();

        MediaList seen = new MediaList
        {
            Name = "Seen",
            Description = "",
            Icon = "",
            IsSystem = true,
            Movies = movies,
            Shows = shows
        };

        context.MediaLists.Add(seen);

        await context.SaveChangesAsync();
        logger.LogInformation("Import terminé");
    }

    private static async Task ImportMovieAsync(ApiDbContext context, TMDbService tmdbService, int tmdbId, ILogger logger)
    {
        if (await context.Movies.AnyAsync(m => m.TmdbId == tmdbId))
        {
            logger.LogDebug("Film déjà existant: TMDb {TmdbId}", tmdbId);
            return;
        }

        TMDbMovieResponse? tmdbMovie = await tmdbService.GetMovieAsync(tmdbId);
        if (tmdbMovie == null)
        {
            logger.LogWarning("Film non trouvé sur TMDb: {TmdbId}", tmdbId);
            return;
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
            Genres = string.Join(", ", tmdbMovie.Genres.Select(g => g.Name))
        };

        context.Movies.Add(movie);
        logger.LogInformation("Film ajouté: {Title}", movie.Title);
    }

    private static async Task ImportShowAsync(ApiDbContext context, TMDbService tmdbService, int tmdbId, ILogger logger)
    {
        if (await context.Shows.AnyAsync(s => s.TmdbId == tmdbId))
        {
            logger.LogDebug("Série déjà existante: TMDb {TmdbId}", tmdbId);
            return;
        }

        TMDbShowResponse? tmdbShow = await tmdbService.GetShowAsync(tmdbId);
        if (tmdbShow == null)
        {
            logger.LogWarning("Série non trouvée sur TMDb: {TmdbId}", tmdbId);
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
            Genres = string.Join(", ", tmdbShow.Genres.Select(g => g.Name))
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
                ShowId = show.Id
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
                    SeasonId = season.Id
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
}