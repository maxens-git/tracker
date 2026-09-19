using Tracker.Models;

namespace Tracker.ModelsDTO;

public class MediaListItemDto
{
    public int TmdbId { get; set; }
    public string MediaType { get; set; } = "";
    public string? PosterPath { get; set; }
    public string? Title { get; set; }
    public bool Seen { get; set; }
    public bool Liked { get; set; }
    public DateTime AddedAt { get; set; }

    public MediaListItemDto(MediaListItem item, UserMedia? um)
    {
        TmdbId = item.TmdbId;
        MediaType = item.MediaType.ToApiString();
        PosterPath = item.PosterPath ?? um?.PosterPath;
        Title = item.Title;
        Seen = um?.Seen ?? false;
        Liked = um?.Liked ?? false;
        AddedAt = item.AddedAt;
    }

    public MediaListItemDto(UserMedia m)
    {
        TmdbId = m.TmdbId;
        MediaType = m.MediaType.ToApiString();
        PosterPath = m.PosterPath;
        Title = m.Title;
        Seen = m.Seen;
        Liked = m.Liked;
        AddedAt = m.AddedAt;
    }
}
