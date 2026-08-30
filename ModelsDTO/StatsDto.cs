using System.Collections.Generic;

namespace Tracker.ModelsDTO;

public class StatsDto
{
    public int MoviesSeenCount { get; set; }
    public int ShowsSeenCount { get; set; }
    public int EpisodesSeenCount { get; set; }

    public int TotalRuntimeMinutes { get; set; }
    public double TotalRuntimeHours => TotalRuntimeMinutes / 60d;

    public List<StatsYearBucket> MoviesSeenByYear { get; set; } = new();
    public List<StatsMonthBucket> MoviesSeenByMonth { get; set; } = new();

    public List<StatsYearBucket> EpisodesSeenByYear { get; set; } = new();
    public List<StatsMonthBucket> EpisodesSeenByMonth { get; set; } = new();

    public List<StatsGenreBucket> FavoriteGenres { get; set; } = new();
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
