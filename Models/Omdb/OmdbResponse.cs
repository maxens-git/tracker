using System.Text.Json.Serialization;

namespace Tracker.Models.Omdb;

public class OmdbResponse
{
    [JsonPropertyName("Response")]
    public string? Response { get; set; }

    [JsonPropertyName("Error")]
    public string? Error { get; set; }

    [JsonPropertyName("imdbID")]
    public string? ImdbId { get; set; }

    [JsonPropertyName("imdbRating")]
    public string? ImdbRating { get; set; }

    [JsonPropertyName("imdbVotes")]
    public string? ImdbVotes { get; set; }

    [JsonPropertyName("Ratings")]
    public List<OmdbRating> Ratings { get; set; } = new();
}

public class OmdbRating
{
    [JsonPropertyName("Source")]
    public string? Source { get; set; }

    [JsonPropertyName("Value")]
    public string? Value { get; set; }
}
