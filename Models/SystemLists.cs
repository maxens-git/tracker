namespace Tracker.Models;

/// <summary>
/// Noms et icônes des listes système (non modifiables/supprimables par l'utilisateur).
/// Source unique partagée par le seeder, les services et les contrôleurs.
/// </summary>
public static class SystemLists
{
    public const string Watchlist = "Watchlist";
    public const string Seen = "Seen";
    public const string Liked = "J'aime";

    /// <summary>Icône par défaut de chaque liste système, indexée par son nom.</summary>
    public static readonly IReadOnlyDictionary<string, string> Icons = new Dictionary<string, string>
    {
        [Watchlist] = "🎬",
        [Seen] = "✅",
        [Liked] = "❤️",
    };

    /// <summary>Noms de toutes les listes système, dans l'ordre de création.</summary>
    public static readonly IReadOnlyList<string> Names = new[] { Watchlist, Seen, Liked };
}
