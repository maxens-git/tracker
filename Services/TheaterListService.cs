using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Services;

/// <summary>
/// Gère les listes de cinémas (regroupements de codes Allociné consultés ensemble).
/// Valide les codes via <see cref="AllocineService.NormalizeCode"/> et garantit qu'au plus
/// une liste est « par défaut ». Les erreurs d'entrée lèvent <see cref="InvalidOperationException"/>.
/// </summary>
public class TheaterListService(ApiDbContext context)
{
    public async Task<IReadOnlyList<TheaterListDto>> GetAll()
    {
        List<TheaterList> lists = await context.TheaterLists
            .Include(l => l.Items)
            .OrderByDescending(l => l.IsDefault).ThenBy(l => l.Name)
            .ToListAsync();

        return lists.Select(l => new TheaterListDto(l)).ToList();
    }

    public async Task<TheaterListDto?> Get(int id)
    {
        TheaterList? list = await context.TheaterLists
            .Include(l => l.Items)
            .FirstOrDefaultAsync(l => l.Id == id);

        return list is null ? null : new TheaterListDto(list);
    }

    public async Task<TheaterListDto> Create(TheaterListSaveDto dto)
    {
        (string name, List<string> codes) = Validate(dto);

        if (await context.TheaterLists.AnyAsync(l => l.Name == name))
            throw new InvalidOperationException("Une liste porte déjà ce nom.");

        var list = new TheaterList(name);
        SetItems(list, codes);

        context.TheaterLists.Add(list);
        await context.SaveChangesAsync();

        return new TheaterListDto(list);
    }

    public async Task<TheaterListDto?> Update(int id, TheaterListSaveDto dto)
    {
        (string name, List<string> codes) = Validate(dto);

        TheaterList? list = await context.TheaterLists
            .Include(l => l.Items)
            .FirstOrDefaultAsync(l => l.Id == id);
        if (list is null) return null;

        if (await context.TheaterLists.AnyAsync(l => l.Name == name && l.Id != id))
            throw new InvalidOperationException("Une liste porte déjà ce nom.");

        list.Name = name;
        list.UpdatedAt = DateTime.UtcNow;
        context.TheaterListItems.RemoveRange(list.Items);
        list.Items.Clear();
        SetItems(list, codes);

        await context.SaveChangesAsync();
        return new TheaterListDto(list);
    }

    public async Task<bool> Delete(int id)
    {
        TheaterList? list = await context.TheaterLists.FindAsync(id);
        if (list is null) return false;

        context.TheaterLists.Remove(list);
        await context.SaveChangesAsync();
        return true;
    }

    /// <summary>Définit la liste par défaut ; retire le drapeau de toutes les autres (au plus une à true).</summary>
    public async Task<bool> SetDefault(int id)
    {
        List<TheaterList> all = await context.TheaterLists.ToListAsync();
        TheaterList? target = all.FirstOrDefault(l => l.Id == id);
        if (target is null) return false;

        foreach (TheaterList l in all)
            l.IsDefault = l.Id == id;

        await context.SaveChangesAsync();
        return true;
    }

    /// <summary>Normalise nom + codes (validés, dédupliqués, ordre conservé). Lève si invalide.</summary>
    private static (string Name, List<string> Codes) Validate(TheaterListSaveDto dto)
    {
        string name = (dto.Name ?? "").Trim();
        if (string.IsNullOrEmpty(name))
            throw new InvalidOperationException("Le nom de la liste est requis.");

        var codes = new List<string>();
        var seen = new HashSet<string>();
        foreach (string raw in dto.Codes ?? [])
        {
            string code = AllocineService.NormalizeCode(raw); // lève si code invalide
            if (seen.Add(code)) codes.Add(code);
        }

        return (name, codes);
    }

    private static void SetItems(TheaterList list, List<string> codes)
    {
        for (int i = 0; i < codes.Count; i++)
            list.Items.Add(new TheaterListItem(list.Id, codes[i], i));
    }
}
