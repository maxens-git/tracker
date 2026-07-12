using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using System.Text.Json.Serialization;
using Tracker.Data;
using Tracker.Models;

namespace Tracker.Services;

public sealed record BackfillSeenMediaMetadataOptions(bool DryRun, bool Force, int? Limit, bool All)
{
    public static BackfillSeenMediaMetadataOptions FromArgs(string[] args)
    {
        bool dryRun = args.Contains("--dry-run");
        bool force = args.Contains("--force");
        bool all = args.Contains("--all");
        int? limit = null;

        int limitIndex = Array.IndexOf(args, "--limit");
        if (limitIndex >= 0 && limitIndex + 1 < args.Length && int.TryParse(args[limitIndex + 1], out int parsedLimit))
            limit = parsedLimit;

        return new BackfillSeenMediaMetadataOptions(dryRun, force, limit, all);
    }
}

public class SeenMediaMetadataBackfillService(
    ApiDbContext context,
    HttpClient httpClient,
    IConfiguration configuration,
    ILogger<SeenMediaMetadataBackfillService> logger)
{
    private readonly JsonSerializerOptions jsonOptions = new(JsonSerializerDefaults.Web);

    public async Task Run(BackfillSeenMediaMetadataOptions options, CancellationToken cancellationToken = default)
    {
        string apiKey = configuration["TMDB:ApiKey"] ?? "";
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new InvalidOperationException("TMDB:ApiKey est requis pour lancer le backfill.");

        string baseUrl = (configuration["TMDB:BaseUrl"] ?? "https://api.themoviedb.org/3").TrimEnd('/');
        string language = configuration["TMDB:Language"] ?? "fr-FR";

        List<UserMedia> seenMedia = await SeenMediaQuery(options).ToListAsync(cancellationToken);

        int mediaGenreUpdates = 0;
        int movieRuntimeUpdates = 0;
        int showRuntimeUpdates = 0;

        foreach (UserMedia media in seenMedia)
        {
            if (media.MediaType == MediaType.Movie)
            {
                TmdbMovieDetail? movie = await GetTmdb<TmdbMovieDetail>(baseUrl, apiKey, language, $"/movie/{media.TmdbId}", cancellationToken);
                if (movie == null) continue;

                if (ShouldUpdate(media.Runtime, options) && movie.Runtime is > 0)
                {
                    media.Runtime = movie.Runtime;
                    movieRuntimeUpdates++;
                }

                if (ShouldUpdateGenres(media, options) && SerializeGenreNames(movie.Genres) is { } genresJson)
                {
                    media.GenreNamesJson = genresJson;
                    mediaGenreUpdates++;
                }
            }
            else
            {
                TmdbShowDetail? show = await GetTmdb<TmdbShowDetail>(baseUrl, apiKey, language, $"/tv/{media.TmdbId}", cancellationToken);
                if (show == null) continue;

                if (ShouldUpdate(media.Runtime, options) && EstimateShowRuntime(show) is { } showRuntime)
                {
                    media.Runtime = showRuntime;
                    showRuntimeUpdates++;
                }

                if (ShouldUpdateGenres(media, options) && SerializeGenreNames(show.Genres) is { } genresJson)
                {
                    media.GenreNamesJson = genresJson;
                    mediaGenreUpdates++;
                }
            }

            await Task.Delay(80, cancellationToken);
        }

        int episodeRuntimeUpdates = await BackfillEpisodeRuntimes(baseUrl, apiKey, language, options, cancellationToken);

        if (!options.DryRun)
            await context.SaveChangesAsync(cancellationToken);

        logger.LogInformation(
            "Backfill terminé. Médias lus: {MediaCount}. Genres média: {GenreUpdates}. Runtime films: {MovieRuntimeUpdates}. Runtime séries fallback: {ShowRuntimeUpdates}. Runtime épisodes: {EpisodeRuntimeUpdates}. Dry run: {DryRun}.",
            seenMedia.Count, mediaGenreUpdates, movieRuntimeUpdates, showRuntimeUpdates, episodeRuntimeUpdates, options.DryRun);
    }

    private IQueryable<UserMedia> SeenMediaQuery(BackfillSeenMediaMetadataOptions options)
    {
        // Par défaut, on ne backfill que les médias vus. --all étend à tous les UserMedia,
        // y compris ceux référencés uniquement par des listes (AddItem crée toujours une ligne).
        IQueryable<UserMedia> query = context.UserMedia;

        if (!options.All)
            query = query.Where(m => m.Seen);

        query = query
            .OrderBy(m => m.MediaType)
            .ThenBy(m => m.TmdbId);

        if (!options.Force)
            query = query.Where(m => m.Runtime == null || m.GenreNamesJson == null || m.GenreNamesJson == "");

        if (options.Limit is { } limit)
            query = query.Take(limit);

        return query;
    }

    private async Task<int> BackfillEpisodeRuntimes(
        string baseUrl,
        string apiKey,
        string language,
        BackfillSeenMediaMetadataOptions options,
        CancellationToken cancellationToken)
    {
        List<UserEpisode> episodes = await context.UserEpisodes
            .Where(e => e.Seen && (options.Force || e.Runtime == null))
            .OrderBy(e => e.ShowTmdbId)
            .ThenBy(e => e.SeasonNumber)
            .ThenBy(e => e.EpisodeNumber)
            .ToListAsync(cancellationToken);

        int updates = 0;

        foreach (IGrouping<(int ShowTmdbId, int SeasonNumber), UserEpisode> group in episodes.GroupBy(e => (e.ShowTmdbId, e.SeasonNumber)))
        {
            TmdbSeasonDetail? season = await GetTmdb<TmdbSeasonDetail>(
                baseUrl,
                apiKey,
                language,
                $"/tv/{group.Key.ShowTmdbId}/season/{group.Key.SeasonNumber}",
                cancellationToken);

            if (season == null) continue;

            Dictionary<int, int> runtimesByEpisode = (season.Episodes ?? [])
                .Where(e => e.Runtime is > 0)
                .ToDictionary(e => e.EpisodeNumber, e => e.Runtime!.Value);

            foreach (UserEpisode episode in group)
            {
                if (runtimesByEpisode.TryGetValue(episode.EpisodeNumber, out int runtime)
                    && (options.Force || episode.Runtime == null))
                {
                    episode.Runtime = runtime;
                    updates++;
                }
            }

            await Task.Delay(80, cancellationToken);
        }

        return updates;
    }

    private async Task<T?> GetTmdb<T>(
        string baseUrl,
        string apiKey,
        string language,
        string path,
        CancellationToken cancellationToken)
    {
        string separator = path.Contains('?') ? "&" : "?";
        string url = $"{baseUrl}{path}{separator}api_key={Uri.EscapeDataString(apiKey)}&language={Uri.EscapeDataString(language)}";

        HttpResponseMessage response;
        try
        {
            response = await httpClient.GetAsync(url, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex, "Impossible d'appeler TMDB {Path}.", path);
            return default;
        }

        using (response)
        {
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("TMDB {Path} a répondu {StatusCode}.", path, (int)response.StatusCode);
                return default;
            }

            await using Stream stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            return await JsonSerializer.DeserializeAsync<T>(stream, jsonOptions, cancellationToken);
        }
    }

    private static bool ShouldUpdate(int? value, BackfillSeenMediaMetadataOptions options) =>
        options.Force || value == null;

    private static bool ShouldUpdateGenres(UserMedia media, BackfillSeenMediaMetadataOptions options) =>
        options.Force || string.IsNullOrWhiteSpace(media.GenreNamesJson);

    private static string? SerializeGenreNames(IEnumerable<TmdbGenre>? genres)
    {
        if (genres == null) return null;

        List<string> names = genres
            .Select(g => g.Name.Trim())
            .Where(name => name.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        return names.Count > 0 ? JsonSerializer.Serialize(names) : null;
    }

    private static int? EstimateShowRuntime(TmdbShowDetail show)
    {
        int averageRuntime = show.EpisodeRunTime?.FirstOrDefault(r => r > 0) ?? 0;
        if (averageRuntime <= 0 || show.NumberOfEpisodes is not > 0) return null;
        return averageRuntime * show.NumberOfEpisodes.Value;
    }

    private sealed record TmdbGenre(int Id, string Name);

    private sealed record TmdbMovieDetail(int? Runtime, List<TmdbGenre>? Genres);

    private sealed record TmdbShowDetail(
        [property: JsonPropertyName("episode_run_time")] List<int>? EpisodeRunTime,
        [property: JsonPropertyName("number_of_episodes")] int? NumberOfEpisodes,
        List<TmdbGenre>? Genres);

    private sealed record TmdbSeasonDetail(List<TmdbEpisodeDetail>? Episodes);

    private sealed record TmdbEpisodeDetail(
        [property: JsonPropertyName("episode_number")] int EpisodeNumber,
        int? Runtime);
}
