using Tracker.Models;

namespace Tracker.ModelsDTO;

public class EpisodeSeenDto
{
    public int SeasonNumber { get; set; }
    public int EpisodeNumber { get; set; }
    public bool Seen { get; set; }

    public EpisodeSeenDto(UserEpisode e)
    {
        SeasonNumber = e.SeasonNumber;
        EpisodeNumber = e.EpisodeNumber;
        Seen = e.Seen;
    }
}

public class MarkSeasonSeenDto
{
    public bool Seen { get; set; }
    public List<int> EpisodeNumbers { get; set; } = new();
}

public class MarkShowSeenDto
{
    public bool Seen { get; set; }
    public string? PosterPath { get; set; }
    public List<MediaGenreDto> Genres { get; set; } = new();
    public List<SeasonEpisodesDto> Seasons { get; set; } = new();
}

public class SeasonEpisodesDto
{
    public int SeasonNumber { get; set; }
    public List<int> EpisodeNumbers { get; set; } = new();
}
