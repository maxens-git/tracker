using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("UserEpisodes")]
public class UserEpisode
{
    public UserEpisode(int showTmdbId, int seasonNumber, int episodeNumber, bool seen)
    {
        ShowTmdbId = showTmdbId;
        SeasonNumber = seasonNumber;
        EpisodeNumber = episodeNumber;
        Seen = seen;
    }

    [Key]
    public int Id { get; set; }

    public int ShowTmdbId { get; set; }

    public int SeasonNumber { get; set; }

    public int EpisodeNumber { get; set; }

    /// <summary>Dérivé de <see cref="WatchCount"/> &gt; 0, maintenu en synchronisation par <see cref="Services.WatchHistoryService"/>.</summary>
    public bool Seen { get; set; } = false;

    /// <summary>Nombre de visionnages enregistrés (voir <see cref="WatchEvents"/> pour l'historique daté).</summary>
    [ConcurrencyCheck]
    public int WatchCount { get; set; } = 0;

    public int? Runtime { get; set; }

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;

    public List<UserEpisodeWatchEvent> WatchEvents { get; set; } = new();
}
