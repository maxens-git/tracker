namespace Tracker.ModelsDTO;

/// <summary>Un indexeur torrent configuré dans Prowlarr.</summary>
public record IndexerDto(int Id, string Name);

/// <summary>Une catégorie de recherche Prowlarr (Torznab), ex. 2000 = Films, 5000 = Séries.</summary>
public record CategoryDto(int Id, string Name);

/// <summary>Un résultat de recherche torrent renvoyé par Prowlarr (protocole torrent + magnet disponible).</summary>
public record TorrentResultDto(
    string Title,
    long Size,
    int Seeders,
    int Leechers,
    string Indexer,
    string MagnetUrl,
    string? Category,
    DateTimeOffset? PublishDate);

/// <summary>Requête de débridage : le magnet choisi par l'utilisateur.</summary>
public record DebridRequestDto(string Magnet);

/// <summary>Un fichier d'un torrent débridé : <paramref name="Link"/> est le lien AllDebrid « verrouillé »,
/// à passer à /unlock pour obtenir le lien de téléchargement direct.</summary>
public record DebridFileDto(string Filename, long Size, string Link);

/// <summary>Résultat d'un débridage : la liste des fichiers (sans lien direct encore généré).</summary>
public record DebridResultDto(IReadOnlyList<DebridFileDto> Files);

/// <summary>Requête d'unlock : un lien AllDebrid verrouillé.</summary>
public record UnlockRequestDto(string Link);

/// <summary>Résultat d'unlock : le lien de téléchargement direct.</summary>
public record UnlockResultDto(string DirectLink);
