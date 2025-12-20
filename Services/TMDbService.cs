using System.Text.Json;
using Tracker.Models.TMDbResponses;

namespace Tracker.Services;

public class TMDbService
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private const string BaseUrl = "https://api.themoviedb.org/3";

    public TMDbService(HttpClient httpClient, string apiKey)
    {
        _httpClient = httpClient;
        _apiKey = apiKey;
    }

    public async Task<TMDbMovieResponse?> GetMovieAsync(int tmdbId)
    {
        var url = $"{BaseUrl}/movie/{tmdbId}?api_key={_apiKey}&language=fr-FR";
        
        var response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbMovieResponse>(json);
    }

    public async Task<TMDbShowResponse?> GetShowAsync(int tmdbId)
    {
        var url = $"{BaseUrl}/tv/{tmdbId}?api_key={_apiKey}&language=fr-FR";
        
        var response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbShowResponse>(json);
    }

    public async Task<TMDbSeasonResponse?> GetSeasonAsync(int showTmdbId, int seasonNumber)
    {
        string url = $"{BaseUrl}/tv/{showTmdbId}/season/{seasonNumber}?api_key={_apiKey}&language=fr-FR";
        
        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbSeasonResponse>(json);
    }

    public async Task<TMDbSearchResponse?> SearchMultiAsync(string query, int page = 1)
    {
        string url = $"{BaseUrl}/search/multi?api_key={_apiKey}&language=fr-FR&query={Uri.EscapeDataString(query)}&page={page}";
        
        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbSearchResponse>(json);
    }

    public async Task<TMDbSearchResponse?> GetTrendingAsync(string mediaType = "all", string timeWindow = "week")
    {
        string url = $"{BaseUrl}/trending/{mediaType}/{timeWindow}?api_key={_apiKey}&language=fr-FR";
        
        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbSearchResponse>(json);
    }

    public async Task<TMDbSearchResponse?> GetPopularMoviesAsync(int page = 1)
    {
        string url = $"{BaseUrl}/movie/popular?api_key={_apiKey}&language=fr-FR&page={page}";
        
        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbSearchResponse>(json);
    }

    public async Task<TMDbSearchResponse?> GetPopularShowsAsync(int page = 1)
    {
        string url = $"{BaseUrl}/tv/popular?api_key={_apiKey}&language=fr-FR&page={page}";
        
        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbSearchResponse>(json);
    }

    public async Task<TMDbSearchResponse?> GetTopRatedAsync(string mediaType = "movie", int page = 1)
    {
        string url = $"{BaseUrl}/{mediaType}/top_rated?api_key={_apiKey}&language=fr-FR&page={page}";
        
        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbSearchResponse>(json);
    }

    public async Task<TMDbSearchResponse?> GetSimilarMoviesAsync(int tmdbId, int page = 1)
    {
        string url = $"{BaseUrl}/movie/{tmdbId}/similar?api_key={_apiKey}&language=fr-FR&page={page}";

        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbSearchResponse>(json);
    }

    public async Task<TMDbSearchResponse?> GetSimilarShowsAsync(int tmdbId, int page = 1)
    {
        string url = $"{BaseUrl}/tv/{tmdbId}/similar?api_key={_apiKey}&language=fr-FR&page={page}";

        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbSearchResponse>(json);
    }

    public async Task<TMDbVideosResponse?> GetMovieVideosAsync(int tmdbId, string? language = null)
    {
        string lang = language ?? "fr-FR";
        string url = $"{BaseUrl}/movie/{tmdbId}/videos?api_key={_apiKey}&language={lang}";

        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbVideosResponse>(json);
    }

    public async Task<TMDbVideosResponse?> GetShowVideosAsync(int tmdbId, string? language = null)
    {
        string lang = language ?? "fr-FR";
        string url = $"{BaseUrl}/tv/{tmdbId}/videos?api_key={_apiKey}&language={lang}";

        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbVideosResponse>(json);
    }

    public async Task<TMDbCreditsResponse?> GetMovieCreditsAsync(int tmdbId)
    {
        string url = $"{BaseUrl}/movie/{tmdbId}/credits?api_key={_apiKey}&language=fr-FR";

        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbCreditsResponse>(json);
    }

    public async Task<TMDbCreditsResponse?> GetShowCreditsAsync(int tmdbId)
    {
        string url = $"{BaseUrl}/tv/{tmdbId}/credits?api_key={_apiKey}&language=fr-FR";

        HttpResponseMessage response = await _httpClient.GetAsync(url);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        string json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<TMDbCreditsResponse>(json);
    }
}
