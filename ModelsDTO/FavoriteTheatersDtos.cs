using Tracker.Models;

namespace Tracker.ModelsDTO;

/// <summary>Un cinéma favori exposé au frontend.</summary>
public record FavoriteTheaterDto(int Id, string Code, bool IsActive, int Position)
{
    public FavoriteTheaterDto(FavoriteTheater f) : this(f.Id, f.Code, f.IsActive, f.Position) { }
}

/// <summary>Ajout d'un cinéma aux favoris : uniquement son code Allociné.</summary>
public record FavoriteTheaterCreateDto(string Code);

/// <summary>Mise à jour de l'état coché / décoché d'un favori.</summary>
public record FavoriteTheaterActiveDto(bool IsActive);
