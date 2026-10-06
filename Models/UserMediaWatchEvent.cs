using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

/// <summary>Un visionnage daté d'un film ou d'une série (<see cref="UserMedia"/>). Plusieurs par média = revisionnages.</summary>
[Table("UserMediaWatchEvents")]
public class UserMediaWatchEvent
{
    public UserMediaWatchEvent(int userMediaId, DateTime watchedAt)
    {
        UserMediaId = userMediaId;
        WatchedAt = watchedAt;
    }

    [Key]
    public int Id { get; set; }

    public int UserMediaId { get; set; }

    public UserMedia? UserMedia { get; set; }

    /// <summary>Date choisie par l'utilisateur pour ce visionnage (peut être antérieure à aujourd'hui).</summary>
    public DateTime WatchedAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
