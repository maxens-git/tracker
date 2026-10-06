using Tracker.Models;

namespace Tracker.ModelsDTO;

/// <summary>Un visionnage daté, tel que renvoyé au frontend (film/série ou épisode).</summary>
public class WatchEventDto
{
    public int Id { get; set; }
    public DateTime WatchedAt { get; set; }

    public WatchEventDto(UserMediaWatchEvent e)
    {
        Id = e.Id;
        WatchedAt = e.WatchedAt;
    }

    public WatchEventDto(UserEpisodeWatchEvent e)
    {
        Id = e.Id;
        WatchedAt = e.WatchedAt;
    }
}
