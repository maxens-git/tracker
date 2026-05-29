using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;

namespace Tracker;

public static class DbSeeder
{
    public static async Task SeedSystemListsAsync(ApiDbContext context)
    {
        foreach (string name in SystemLists.Names)
        {
            bool exists = await context.MediaLists.AnyAsync(l => l.Name == name);
            if (!exists)
            {
                SystemLists.Icons.TryGetValue(name, out string? icon);
                context.MediaLists.Add(new MediaList(name, icon: icon, isSystem: true));
            }
        }

        await context.SaveChangesAsync();
    }
}
