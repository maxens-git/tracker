using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

/// <summary>Nature d'une action utilisateur enregistrée dans le journal d'activité.</summary>
public enum ActivityType
{
    MarkedSeen = 0,
    MarkedUnseen = 1,
    Liked = 2,
    Unliked = 3,
    AddedToList = 4,
    RemovedFromList = 5,
}

/// <summary>
/// Journal des dernières actions de l'utilisateur (vu / aimé / ajout ou retrait d'une liste).
/// La watchlist est traitée comme une liste : <see cref="ListName"/> = "Watchlist".
/// Le nom de la liste est dénormalisé pour rester lisible même après suppression de la liste.
/// </summary>
[Table("ActivityEvents")]
public class ActivityEvent
{
    public ActivityEvent(
        ActivityType type, int tmdbId, MediaType mediaType,
        string? posterPath = null, int? listId = null, string? listName = null)
    {
        Type = type;
        TmdbId = tmdbId;
        MediaType = mediaType;
        PosterPath = posterPath;
        ListId = listId;
        ListName = listName;
    }

    [Key]
    public int Id { get; set; }

    public ActivityType Type { get; set; }

    public int TmdbId { get; set; }

    public MediaType MediaType { get; set; }

    [MaxLength(500)]
    public string? PosterPath { get; set; }

    /// <summary>Identifiant de la liste concernée (null pour vu/aimé ou si la liste a été supprimée).</summary>
    public int? ListId { get; set; }

    [MaxLength(200)]
    public string? ListName { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
