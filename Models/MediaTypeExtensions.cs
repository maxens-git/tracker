namespace Tracker.Models;

/// <summary>
/// Conversions entre l'enum <see cref="MediaType"/> et les chaînes utilisées par l'API/le frontend
/// ("movie", "tv"/"show"). Source unique pour éviter les comparaisons éparpillées.
/// </summary>
public static class MediaTypeExtensions
{
    /// <summary>Convertit une chaîne en <see cref="MediaType"/> ("show"/"tv" → Show, sinon Movie).</summary>
    public static MediaType Parse(string? type) =>
        type?.ToLowerInvariant() is "show" or "tv" ? MediaType.Show : MediaType.Movie;

    /// <summary>Représentation côté API : "movie" ou "tv".</summary>
    public static string ToApiString(this MediaType type) =>
        type == MediaType.Movie ? "movie" : "tv";
}
