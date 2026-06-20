using System.Globalization;
using System.Text.Json;
using Tracker.Models;

namespace Tracker.Services;

public class TmdbReleaseService(HttpClient http, IConfiguration configuration, ILogger<TmdbReleaseService> logger)
{
    private readonly string? apiKey = configuration["TMDB:ApiKey"];
    private readonly string baseUrl = configuration["TMDB:BaseUrl"] ?? "https://api.themoviedb.org/3";
    private readonly string language = configuration["TMDB:Language"] ?? "fr-FR";

    public async Task<List<ReleaseCandidate>> GetUpcomingReleases(
        TrackedMediaRelease media,
        DateOnly today,
        int daysAhead,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(apiKey))
            return [];

        DateOnly maxDate = today.AddDays(daysAhead);
        try
        {
            return media.MediaType == MediaType.Movie
                ? await GetMovieReleases(media, today, maxDate, cancellationToken)
                : await GetShowReleases(media, today, maxDate, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Impossible de récupérer les sorties TMDB pour {Type} {TmdbId}", media.MediaType, media.TmdbId);
            return [];
        }
    }

    private async Task<List<ReleaseCandidate>> GetMovieReleases(
        TrackedMediaRelease media,
        DateOnly today,
        DateOnly maxDate,
        CancellationToken cancellationToken)
    {
        using JsonDocument doc = await GetJson($"/movie/{media.TmdbId}", cancellationToken);
        JsonElement root = doc.RootElement;
        DateOnly? releaseDate = ReadDate(root, "release_date");
        if (!IsInWindow(releaseDate, today, maxDate)) return [];

        string title = ReadString(root, "title") ?? media.Title;
        string? posterPath = ReadString(root, "poster_path") ?? media.PosterPath;
        return [new ReleaseCandidate(media.TmdbId, MediaType.Movie, title, $"movie:{media.TmdbId}:{releaseDate:yyyy-MM-dd}", title, releaseDate!.Value, posterPath)];
    }

    /// <summary>
    /// Liste les saisons « réelles » (numéro &gt; 0) d'une série, datées ou non,
    /// sans filtre de fenêtre. Sert au suivi des nouveautés (saison annoncée mais
    /// pas encore programmée) — contrairement à <see cref="GetUpcomingReleases"/>
    /// qui ne remonte que les sorties datées dans la fenêtre.
    /// </summary>
    public async Task<List<SeasonInfo>> GetShowSeasons(int tmdbId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(apiKey))
            return [];

        try
        {
            using JsonDocument doc = await GetJson($"/tv/{tmdbId}", cancellationToken);
            if (!doc.RootElement.TryGetProperty("seasons", out JsonElement seasons) || seasons.ValueKind != JsonValueKind.Array)
                return [];

            List<SeasonInfo> result = [];
            foreach (JsonElement season in seasons.EnumerateArray())
            {
                int number = ReadInt(season, "season_number") ?? 0;
                if (number <= 0) continue;

                string? airDate = ReadString(season, "air_date");
                if (string.IsNullOrWhiteSpace(airDate)) airDate = null;

                result.Add(new SeasonInfo(
                    number,
                    ReadString(season, "name") ?? $"Saison {number}",
                    airDate,
                    ReadInt(season, "episode_count") ?? 0));
            }
            return result;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Impossible de récupérer les saisons TMDB pour {TmdbId}", tmdbId);
            return [];
        }
    }

    private async Task<List<ReleaseCandidate>> GetShowReleases(
        TrackedMediaRelease media,
        DateOnly today,
        DateOnly maxDate,
        CancellationToken cancellationToken)
    {
        using JsonDocument doc = await GetJson($"/tv/{media.TmdbId}", cancellationToken);
        JsonElement root = doc.RootElement;
        string showTitle = ReadString(root, "name") ?? media.Title;
        string? posterPath = ReadString(root, "poster_path") ?? media.PosterPath;
        List<ReleaseCandidate> releases = [];

        if (root.TryGetProperty("next_episode_to_air", out JsonElement nextEpisode) && nextEpisode.ValueKind == JsonValueKind.Object)
            AddEpisodeRelease(media, showTitle, posterPath, nextEpisode, today, maxDate, releases);

        if (root.TryGetProperty("seasons", out JsonElement seasons) && seasons.ValueKind == JsonValueKind.Array)
        {
            foreach (JsonElement season in seasons.EnumerateArray())
            {
                int seasonNumber = ReadInt(season, "season_number") ?? 0;
                if (seasonNumber <= 0) continue;

                DateOnly? seasonAirDate = ReadDate(season, "air_date");
                if (IsInWindow(seasonAirDate, today, maxDate))
                {
                    releases.Add(new ReleaseCandidate(
                        media.TmdbId,
                        MediaType.Show,
                        showTitle,
                        $"show:{media.TmdbId}:season:{seasonNumber}:{seasonAirDate:yyyy-MM-dd}",
                        $"{showTitle} - saison {seasonNumber}",
                        seasonAirDate!.Value,
                        ReadString(season, "poster_path") ?? posterPath));
                }

                if (seasonAirDate.HasValue && seasonAirDate.Value >= today.AddDays(-30) && seasonAirDate.Value <= maxDate)
                {
                    await AddSeasonEpisodes(media, showTitle, posterPath, seasonNumber, today, maxDate, releases, cancellationToken);
                }
            }
        }

        return releases
            .GroupBy(r => r.ReleaseKey)
            .Select(g => g.First())
            .OrderBy(r => r.ReleaseDate)
            .ToList();
    }

    private async Task AddSeasonEpisodes(
        TrackedMediaRelease media,
        string showTitle,
        string? posterPath,
        int seasonNumber,
        DateOnly today,
        DateOnly maxDate,
        List<ReleaseCandidate> releases,
        CancellationToken cancellationToken)
    {
        using JsonDocument doc = await GetJson($"/tv/{media.TmdbId}/season/{seasonNumber}", cancellationToken);
        if (!doc.RootElement.TryGetProperty("episodes", out JsonElement episodes) || episodes.ValueKind != JsonValueKind.Array)
            return;

        foreach (JsonElement episode in episodes.EnumerateArray())
            AddEpisodeRelease(media, showTitle, posterPath, episode, today, maxDate, releases);
    }

    private static void AddEpisodeRelease(
        TrackedMediaRelease media,
        string showTitle,
        string? posterPath,
        JsonElement episode,
        DateOnly today,
        DateOnly maxDate,
        List<ReleaseCandidate> releases)
    {
        DateOnly? airDate = ReadDate(episode, "air_date");
        if (!IsInWindow(airDate, today, maxDate)) return;

        int seasonNumber = ReadInt(episode, "season_number") ?? 0;
        int episodeNumber = ReadInt(episode, "episode_number") ?? 0;
        string episodeName = ReadString(episode, "name") ?? $"Episode {episodeNumber}";
        releases.Add(new ReleaseCandidate(
            media.TmdbId,
            MediaType.Show,
            showTitle,
            $"show:{media.TmdbId}:s{seasonNumber}:e{episodeNumber}:{airDate:yyyy-MM-dd}",
            $"{showTitle} - S{seasonNumber:00}E{episodeNumber:00} - {episodeName}",
            airDate!.Value,
            posterPath));
    }

    private async Task<JsonDocument> GetJson(string path, CancellationToken cancellationToken)
    {
        Uri uri = BuildUri(path);
        using HttpResponseMessage response = await http.GetAsync(uri, cancellationToken);
        response.EnsureSuccessStatusCode();
        await using Stream stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        return await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
    }

    private Uri BuildUri(string path)
    {
        string separator = path.Contains('?') ? "&" : "?";
        string url = $"{baseUrl.TrimEnd('/')}{path}{separator}api_key={Uri.EscapeDataString(apiKey!)}&language={Uri.EscapeDataString(language)}";
        return new Uri(url);
    }

    private static bool IsInWindow(DateOnly? date, DateOnly today, DateOnly maxDate) =>
        date.HasValue && date.Value >= today && date.Value <= maxDate;

    private static DateOnly? ReadDate(JsonElement element, string property)
    {
        string? raw = ReadString(element, property);
        return DateOnly.TryParseExact(raw, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out DateOnly date)
            ? date
            : null;
    }

    private static string? ReadString(JsonElement element, string property) =>
        element.TryGetProperty(property, out JsonElement value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static int? ReadInt(JsonElement element, string property) =>
        element.TryGetProperty(property, out JsonElement value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out int number)
            ? number
            : null;
}
