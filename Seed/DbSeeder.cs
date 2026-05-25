using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.Models;

namespace Tracker;

public static class DbSeeder
{
    public static async Task SeedSystemListsAsync(ApiDbContext context)
    {
        string[] systemLists = ["Watchlist", "Seen", "J'aime"];

        foreach (string name in systemLists)
        {
            bool exists = await context.MediaLists.AnyAsync(l => l.Name == name);
            if (!exists)
            {
                string? icon = name switch { "Watchlist" => "🎬", "Seen" => "✅", "J'aime" => "❤️", _ => null };
                context.MediaLists.Add(new MediaList(name, icon: icon, isSystem: true));
            }
        }

        await context.SaveChangesAsync();
    }
}
