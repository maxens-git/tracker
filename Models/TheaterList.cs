using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

/// <summary>
/// Une liste de cinémas (codes Allociné) que l'utilisateur consulte ensemble.
/// Une seule liste peut être « par défaut » : elle est chargée à l'ouverture de la page Séances.
/// Distincte des <see cref="MediaList"/> (qui portent sur des œuvres TMDB).
/// </summary>
[Table("TheaterLists")]
public class TheaterList
{
    public TheaterList(string name, bool isDefault = false)
    {
        Name = name;
        IsDefault = isDefault;
    }

    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    /// <summary>Liste chargée automatiquement au démarrage de la page (au plus une à true).</summary>
    public bool IsDefault { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }

    public List<TheaterListItem> Items { get; set; } = new();
}
