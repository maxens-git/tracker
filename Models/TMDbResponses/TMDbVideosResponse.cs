using System.Text.Json.Serialization;

namespace Tracker.Models.TMDbResponses;

public class TMDbVideosResponse
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("results")]
    public List<TMDbVideo> Results { get; set; } = new();
}

public class TMDbVideo
{
    [JsonPropertyName("iso_639_1")]
    public string? Iso639_1 { get; set; }

    [JsonPropertyName("iso_3166_1")]
    public string? Iso3166_1 { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("key")]
    public string Key { get; set; } = string.Empty;

    [JsonPropertyName("site")]
    public string Site { get; set; } = string.Empty;

    [JsonPropertyName("size")]
    public int Size { get; set; }

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("official")]
    public bool Official { get; set; }

    [JsonPropertyName("published_at")]
    public string? PublishedAt { get; set; }

    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;
}
