using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("MediaListItems")]
public class MediaListItem
{
    public MediaListItem(int mediaListId, int tmdbId, MediaType mediaType, string? posterPath = null, string? title = null)
    {
        MediaListId = mediaListId;
        TmdbId = tmdbId;
        MediaType = mediaType;
        PosterPath = posterPath;
        Title = title;
    }

    [Key]
    public int Id { get; set; }

    public int MediaListId { get; set; }
    public MediaList MediaList { get; set; } = null!;

    public int TmdbId { get; set; }

    public MediaType MediaType { get; set; }

    [MaxLength(500)]
    public string? PosterPath { get; set; }

    /// <summary>
    /// Titre (film) ou nom (série) capturé à l'ajout — évite de refaire un appel TMDB
    /// par item pour des opérations en masse (ex. copier tous les titres d'une liste).
    /// Null pour les items ajoutés avant l'introduction de ce champ.
    /// </summary>
    [MaxLength(500)]
    public string? Title { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
}
