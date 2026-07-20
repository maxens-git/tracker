using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

/// <summary>
/// Un cinéma favori (code Allociné, ex. « P0057 ») que l'utilisateur consulte sur la page Séances.
/// Les favoris sont une liste plate : chacun est coché ou non (<see cref="IsActive"/>), ce choix
/// est mémorisé et détermine les salles chargées à l'ouverture. Remplace l'ancien concept de
/// « listes de cinémas ». Distinct des <see cref="MediaList"/> (qui portent sur des œuvres TMDB).
/// </summary>
[Table("FavoriteTheaters")]
public class FavoriteTheater
{
    public FavoriteTheater(string code, int position, bool isActive = true)
    {
        Code = code;
        Position = position;
        IsActive = isActive;
    }

    [Key]
    public int Id { get; set; }

    /// <summary>Code salle Allociné validé (une lettre + 3 à 5 chiffres). Unique.</summary>
    [Required]
    [MaxLength(8)]
    public string Code { get; set; } = string.Empty;

    /// <summary>Coché : les séances de ce cinéma sont affichées. Mémorisé côté serveur.</summary>
    public bool IsActive { get; set; } = true;

    /// <summary>Ordre d'affichage des favoris.</summary>
    public int Position { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }
}
