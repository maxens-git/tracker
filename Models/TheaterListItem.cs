using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

/// <summary>Un cinéma (code Allociné, ex. « P0057 ») membre d'une <see cref="TheaterList"/>.</summary>
[Table("TheaterListItems")]
public class TheaterListItem
{
    public TheaterListItem(int theaterListId, string code, int position)
    {
        TheaterListId = theaterListId;
        Code = code;
        Position = position;
    }

    [Key]
    public int Id { get; set; }

    public int TheaterListId { get; set; }
    public TheaterList TheaterList { get; set; } = null!;

    /// <summary>Code salle Allociné validé (une lettre + 3 à 5 chiffres).</summary>
    [Required]
    [MaxLength(8)]
    public string Code { get; set; } = string.Empty;

    /// <summary>Ordre d'affichage dans la liste.</summary>
    public int Position { get; set; }
}
