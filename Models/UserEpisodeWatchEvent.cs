using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

/// <summary>Un visionnage daté d'un épisode (<see cref="UserEpisode"/>). Plusieurs par épisode = revisionnages.</summary>
[Table("UserEpisodeWatchEvents")]
public class UserEpisodeWatchEvent
{
    public UserEpisodeWatchEvent(int userEpisodeId, DateTime watchedAt)
    {
        UserEpisodeId = userEpisodeId;
        WatchedAt = watchedAt;
    }

    [Key]
    public int Id { get; set; }

    public int UserEpisodeId { get; set; }

    public UserEpisode? UserEpisode { get; set; }

    /// <summary>Date choisie par l'utilisateur pour ce visionnage (peut être antérieure à aujourd'hui).</summary>
    public DateTime WatchedAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
