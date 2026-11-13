using Microsoft.EntityFrameworkCore;
using MySqlConnector;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Services;

/// <summary>
/// Gère les cinémas favoris (codes Allociné consultés sur la page Séances). Liste plate :
/// chaque favori est coché ou non (<see cref="FavoriteTheater.IsActive"/>), état mémorisé.
/// Valide les codes via <see cref="AllocineService.NormalizeCode"/> ; l'ajout est idempotent
/// (un code déjà favori est renvoyé tel quel). Les erreurs d'entrée lèvent
/// <see cref="InvalidOperationException"/>.
/// </summary>
public class FavoriteTheaterService(ApiDbContext context)
{
    public async Task<IReadOnlyList<FavoriteTheaterDto>> GetAll()
    {
        List<FavoriteTheater> favorites = await context.FavoriteTheaters
            .OrderBy(f => f.Position).ThenBy(f => f.Id)
            .ToListAsync();

        return favorites.Select(f => new FavoriteTheaterDto(f)).ToList();
    }

    /// <summary>Ajoute un cinéma aux favoris (coché). Idempotent : renvoie l'existant si le code y est déjà.</summary>
    public async Task<FavoriteTheaterDto> Add(FavoriteTheaterCreateDto dto)
    {
        string code = AllocineService.NormalizeCode(dto.Code ?? ""); // lève si code invalide

        FavoriteTheater? existing = await context.FavoriteTheaters.FirstOrDefaultAsync(f => f.Code == code);
        if (existing is not null) return new FavoriteTheaterDto(existing);

        int nextPosition = (await context.FavoriteTheaters.MaxAsync(f => (int?)f.Position) ?? -1) + 1;

        var favorite = new FavoriteTheater(code, nextPosition);
        context.FavoriteTheaters.Add(favorite);
        try
        {
            await context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (ex.InnerException is MySqlException { Number: 1062 })
        {
            // Une autre requête a pu ajouter le même code entre la lecture et l'insertion.
            context.Entry(favorite).State = EntityState.Detached;
            existing = await context.FavoriteTheaters.FirstOrDefaultAsync(f => f.Code == code);
            if (existing is null) throw;
            return new FavoriteTheaterDto(existing);
        }

        return new FavoriteTheaterDto(favorite);
    }

    public async Task<bool> Remove(int id)
    {
        FavoriteTheater? favorite = await context.FavoriteTheaters.FindAsync(id);
        if (favorite is null) return false;

        context.FavoriteTheaters.Remove(favorite);
        await context.SaveChangesAsync();
        return true;
    }

    /// <summary>Coche / décoche un favori (état d'affichage mémorisé).</summary>
    public async Task<bool> SetActive(int id, bool isActive)
    {
        FavoriteTheater? favorite = await context.FavoriteTheaters.FindAsync(id);
        if (favorite is null) return false;

        favorite.IsActive = isActive;
        favorite.UpdatedAt = DateTime.UtcNow;
        await context.SaveChangesAsync();
        return true;
    }
}
