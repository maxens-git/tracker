namespace Tracker.Options;

public class ConnectionStringsOptions
{
    public const string SectionName = "ConnectionStrings";

    public string DefaultConnection { get; set; } = string.Empty;

    /// <summary>
    /// Version du serveur MySQL (ex. « 8.0.36-mysql »). Optionnelle : si elle est absente,
    /// elle est détectée à la connexion. La renseigner évite tout aller-retour vers la base
    /// au démarrage, et donc toute dépendance à sa disponibilité à cet instant.
    /// </summary>
    public string? ServerVersion { get; set; }
}
