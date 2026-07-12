using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

/// <summary>
/// Un torrent mis de côté par l'utilisateur pour le télécharger plus tard.
/// Indépendant de la watchlist et des listes (qui portent sur des médias TMDB) :
/// un marque-page torrent identifie un magnet, pas une œuvre.
/// </summary>
[Table("TorrentBookmarks")]
public class TorrentBookmark
{
    public TorrentBookmark(
        string title,
        long size,
        int seeders,
        int leechers,
        string indexer,
        string magnetUrl,
        string infoHash,
        string? category = null,
        DateTimeOffset? publishDate = null)
    {
        Title = title;
        Size = size;
        Seeders = seeders;
        Leechers = leechers;
        Indexer = indexer;
        MagnetUrl = magnetUrl;
        InfoHash = infoHash;
        Category = category;
        PublishDate = publishDate;
    }

    [Key]
    public int Id { get; set; }

    [MaxLength(1000)]
    public string Title { get; set; }

    public long Size { get; set; }

    public int Seeders { get; set; }

    public int Leechers { get; set; }

    [MaxLength(200)]
    public string Indexer { get; set; }

    /// <summary>Magnet complet : trop long pour être indexé, stocké en TEXT.</summary>
    public string MagnetUrl { get; set; }

    /// <summary>
    /// Clé de déduplication indexée : infohash (btih) extrait du magnet, ou à défaut
    /// le SHA1 hex du magnet. Bornée pour respecter les limites d'index MySQL.
    /// </summary>
    [MaxLength(64)]
    public string InfoHash { get; set; }

    [MaxLength(200)]
    public string? Category { get; set; }

    public DateTimeOffset? PublishDate { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
}
