using System.Collections.Generic;

namespace Tracker.ModelsDTO;

public class StatsDto
{
    public int MoviesSeenCount { get; set; }
    public int ShowsSeenCount { get; set; }
    public int EpisodesSeenCount { get; set; }

    /// <summary>Nombre total de visionnages (revisionnages inclus), à distinguer de <see cref="MoviesSeenCount"/> (titres distincts).</summary>
    public int MoviesWatchCount { get; set; }

    /// <summary>Nombre total de visionnages d'épisodes (revisionnages inclus).</summary>
    public int EpisodesWatchCount { get; set; }

    public int TotalRuntimeMinutes { get; set; }
    public double TotalRuntimeHours => TotalRuntimeMinutes / 60d;

    public List<StatsYearBucket> MoviesSeenByYear { get; set; } = new();
    public List<StatsMonthBucket> MoviesSeenByMonth { get; set; } = new();

    public List<StatsYearBucket> EpisodesSeenByYear { get; set; } = new();
    public List<StatsMonthBucket> EpisodesSeenByMonth { get; set; } = new();

    public List<StatsGenreBucket> FavoriteGenres { get; set; } = new();

    public List<MostRewatchedDto> MostRewatched { get; set; } = new();
}

/// <summary>Film, série ou épisode revu au moins une fois (<see cref="WatchCount"/> &gt;= 2).</summary>
public class MostRewatchedDto
{
    public int TmdbId { get; set; }
    public string MediaType { get; set; } = "";
    public string? Title { get; set; }
    public string? PosterPath { get; set; }
    public int? SeasonNumber { get; set; }
    public int? EpisodeNumber { get; set; }
    public int WatchCount { get; set; }
}

public class StatsYearBucket
{
    public int Year { get; set; }
    public int Count { get; set; }
}

public class StatsMonthBucket
{
    public int Year { get; set; }
    public int Month { get; set; }
    public int Count { get; set; }
}

public class StatsGenreBucket
{
    public string Name { get; set; } = "";
    public int Count { get; set; }
    public int Percentage { get; set; }
}

public class StatsListGenresDto
{
    public int ListId { get; set; }
    public string Name { get; set; } = "";
    public bool IsSystem { get; set; }
    public List<StatsGenreBucket> Genres { get; set; } = new();
}
