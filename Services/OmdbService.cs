using System.Globalization;
using System.Net.Http.Json;
using Tracker.Models;
using Tracker.Models.Omdb;

namespace Tracker.Services;

public class OmdbService
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private const string BaseUrl = "https://www.omdbapi.com/";

    public OmdbService(HttpClient httpClient, string apiKey)
    {
        _httpClient = httpClient;
        _apiKey = apiKey;
    }

    public async Task<OmdbRatingsResult> GetExternalRatingsAsync(string? imdbId, string title, int? year)
    {
        if (string.IsNullOrWhiteSpace(_apiKey))
        {
            return new OmdbRatingsResult();
        }

        string query = imdbId is not null
            ? $"?apikey={_apiKey}&i={imdbId}"
            : $"?apikey={_apiKey}&t={Uri.EscapeDataString(title)}";

        if (year.HasValue)
        {
            query += $"&y={year.Value}";
        }

        HttpResponseMessage response = await _httpClient.GetAsync(BaseUrl + query);
        if (!response.IsSuccessStatusCode)
        {
            return new OmdbRatingsResult { RateLimited = IsRateLimitStatus(response.StatusCode) };
        }

        OmdbResponse? payload = await response.Content.ReadFromJsonAsync<OmdbResponse>();
        if (payload == null || !string.Equals(payload.Response, "True", StringComparison.OrdinalIgnoreCase))
        {
            bool limit = payload?.Error != null && payload.Error.Contains("limit", StringComparison.OrdinalIgnoreCase);
            return new OmdbRatingsResult { RateLimited = limit };
        }

        double? imdbRating = TryParseDouble(payload.ImdbRating);
        long? imdbVotes = TryParseVotes(payload.ImdbVotes);
        double? rottenTomatoes = ExtractRottenTomatoes(payload.Ratings);

        return new OmdbRatingsResult
        {
            Ratings = new MediaRatings
            {
                ImdbRating = imdbRating,
                ImdbVotes = imdbVotes,
                RottenTomatoesRating = rottenTomatoes
            }
        };
    }

    private static bool IsRateLimitStatus(System.Net.HttpStatusCode statusCode)
    {
        return statusCode == System.Net.HttpStatusCode.TooManyRequests
            || statusCode == System.Net.HttpStatusCode.Forbidden
            || statusCode == System.Net.HttpStatusCode.Unauthorized;
    }

    private static double? ExtractRottenTomatoes(IEnumerable<OmdbRating> ratings)
    {
        string? value = ratings.FirstOrDefault(r => string.Equals(r.Source, "Rotten Tomatoes", StringComparison.OrdinalIgnoreCase))?.Value;
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (value.TrimEnd().EndsWith("%", StringComparison.Ordinal))
        {
            string numeric = value.Replace("%", string.Empty).Trim();
            if (double.TryParse(numeric, NumberStyles.Any, CultureInfo.InvariantCulture, out double percent))
            {
                return percent;
            }
        }

        return null;
    }

    private static double? TryParseDouble(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return null;
        }

        if (double.TryParse(raw, NumberStyles.Any, CultureInfo.InvariantCulture, out double value))
        {
            return value;
        }

        return null;
    }

    private static long? TryParseVotes(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return null;
        }

        string normalized = raw.Replace(",", string.Empty).Trim();
        if (long.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, out long votes))
        {
            return votes;
        }

        return null;
    }
}

public class OmdbRatingsResult
{
    public MediaRatings? Ratings { get; set; }
    public bool RateLimited { get; set; }
}
