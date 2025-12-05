using System.Text.Json.Serialization;

namespace Tracker.Models.JustWatch;

public class JustWatchItem
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("year")]
    public int? Year { get; set; }

    [JsonPropertyName("url")]
    public string? Url { get; set; }

    [JsonPropertyName("imdbId")]
    public string? ImdbId { get; set; }

    [JsonPropertyName("tmdbId")]
    public string? TmdbId { get; set; }

    [JsonPropertyName("imdbScore")]
    public double? ImdbScore { get; set; }

    [JsonPropertyName("tmdbScore")]
    public double? TmdbScore { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTime? CreatedAt { get; set; }

    public bool IsShow => Type == "SHOW";
    public bool IsMovie => Type == "MOVIE";
}
