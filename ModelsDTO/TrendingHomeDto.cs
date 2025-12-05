using Tracker.Models.TMDbResponses;

namespace Tracker.ModelsDTO;

public class TrendingHomeDto
{
    public TMDbSearchResult? FeaturedItem { get; set; }
    public List<TMDbSearchResult> TrendingWeek { get; set; } = new();
    public List<TMDbSearchResult> PopularMovies { get; set; } = new();
    public List<TMDbSearchResult> PopularShows { get; set; } = new();
    public List<TMDbSearchResult> TopRated { get; set; } = new();
}
