using Tracker.Models;

namespace Tracker.ModelsDTO;

/// <summary>Un torrent mis de côté, tel que renvoyé au frontend (inclut l'Id pour la suppression).</summary>
public record TorrentBookmarkDto(
    int Id,
    string Title,
    long Size,
    int Seeders,
    int Leechers,
    string Indexer,
    string MagnetUrl,
    string? Category,
    DateTimeOffset? PublishDate,
    DateTime AddedAt)
{
    public TorrentBookmarkDto(TorrentBookmark b) : this(
        b.Id, b.Title, b.Size, b.Seeders, b.Leechers, b.Indexer, b.MagnetUrl, b.Category, b.PublishDate, b.AddedAt)
    {
    }
}

/// <summary>Corps de création d'un marque-page : les champs d'un résultat de recherche torrent.</summary>
public record TorrentBookmarkCreateDto(
    string Title,
    long Size,
    int Seeders,
    int Leechers,
    string Indexer,
    string MagnetUrl,
    string? Category,
    DateTimeOffset? PublishDate);
