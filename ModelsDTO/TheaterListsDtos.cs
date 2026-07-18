using Tracker.Models;

namespace Tracker.ModelsDTO;

/// <summary>Un cinéma membre d'une liste, exposé au frontend.</summary>
public record TheaterListItemDto(string Code, int Position)
{
    public TheaterListItemDto(TheaterListItem item) : this(item.Code, item.Position) { }
}

/// <summary>Une liste de cinémas avec ses membres, ordonnés par position.</summary>
public record TheaterListDto(
    int Id,
    string Name,
    bool IsDefault,
    IReadOnlyList<TheaterListItemDto> Items)
{
    public TheaterListDto(TheaterList list) : this(
        list.Id,
        list.Name,
        list.IsDefault,
        list.Items.OrderBy(i => i.Position).Select(i => new TheaterListItemDto(i)).ToList())
    { }
}

/// <summary>Création / mise à jour d'une liste : nom + codes cinéma (l'ordre définit la position).</summary>
public record TheaterListSaveDto(string Name, IReadOnlyList<string> Codes);
