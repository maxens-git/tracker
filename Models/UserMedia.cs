using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

public enum MediaType { Movie = 0, Show = 1 }

[Table("UserMedia")]
public class UserMedia
{
    public UserMedia(int tmdbId, MediaType mediaType, string? posterPath = null, int? runtime = null, string? genreNamesJson = null, string? title = null)
    {
        TmdbId = tmdbId;
        MediaType = mediaType;
        PosterPath = posterPath;
        Runtime = runtime;
        GenreNamesJson = genreNamesJson;
        Title = title;
    }

    [Key]
    public int Id { get; set; }

    public int TmdbId { get; set; }

    public MediaType MediaType { get; set; }

    public bool Seen { get; set; } = false;

    public bool Liked { get; set; } = false;

    [MaxLength(500)]
    public string? PosterPath { get; set; }

    /// <summary>
    /// Titre (film) ou nom (série) capturé à l'ajout — évite de refaire un appel TMDB
    /// par item pour des opérations en masse (ex. copier tous les titres d'une liste).
    /// Null pour les médias ajoutés avant l'introduction de ce champ.
    /// </summary>
    [MaxLength(500)]
    public string? Title { get; set; }

    public int? Runtime { get; set; }

    public string? GenreNamesJson { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
}
