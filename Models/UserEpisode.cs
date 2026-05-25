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

    public bool Seen { get; set; } = false;

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
}
