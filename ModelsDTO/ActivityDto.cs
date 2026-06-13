using Tracker.Models;

namespace Tracker.ModelsDTO;

/// <summary>Entrée du journal d'activité renvoyée au frontend (le titre est résolu via TMDB côté client).</summary>
public class ActivityDto
{
    public int Id { get; set; }
    public string Type { get; set; } = "";
    public int TmdbId { get; set; }
    public string MediaType { get; set; } = "";
    public string? PosterPath { get; set; }
    public int? ListId { get; set; }
    public string? ListName { get; set; }
    public int? SeasonNumber { get; set; }
    public int? EpisodeNumber { get; set; }
    public DateTime CreatedAt { get; set; }

    public ActivityDto(ActivityEvent e)
    {
        Id = e.Id;
        Type = e.Type switch
        {
            ActivityType.MarkedSeen => "seen",
            ActivityType.MarkedUnseen => "unseen",
            ActivityType.Liked => "liked",
            ActivityType.Unliked => "unliked",
            ActivityType.AddedToList => "addedToList",
            ActivityType.RemovedFromList => "removedFromList",
            ActivityType.MarkedSeasonSeen => "seasonSeen",
            ActivityType.MarkedSeasonUnseen => "seasonUnseen",
            ActivityType.MarkedEpisodeSeen => "episodeSeen",
            ActivityType.MarkedEpisodeUnseen => "episodeUnseen",
            _ => "unknown",
        };
        TmdbId = e.TmdbId;
        MediaType = e.MediaType.ToApiString();
        PosterPath = e.PosterPath;
        ListId = e.ListId;
        ListName = e.ListName;
        SeasonNumber = e.SeasonNumber;
        EpisodeNumber = e.EpisodeNumber;
        CreatedAt = e.CreatedAt;
    }
}
