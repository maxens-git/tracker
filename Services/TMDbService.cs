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
}
