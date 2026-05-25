using Tracker.Models;

namespace Tracker.ModelsDTO;

public class UserStateDto
{
    public int TmdbId { get; set; }
    public bool Seen { get; set; }
    public bool Liked { get; set; }
    public List<int> ListIds { get; set; } = new();

    public UserStateDto(int tmdbId, UserMedia? um, List<int> listIds)
    {
        TmdbId = tmdbId;
        Seen = um?.Seen ?? false;
        Liked = um?.Liked ?? false;
        ListIds = listIds;
    }
}
