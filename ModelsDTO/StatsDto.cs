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

    public List<StatsYearBucket> ShowsSeenByYear { get; set; } = new();
    public List<StatsMonthBucket> ShowsSeenByMonth { get; set; } = new();
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
