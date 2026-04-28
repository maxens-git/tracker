using Tracker.Models;

namespace Tracker.ModelsDTO;

public class MediaRatingsDto
{
    public double? TmdbRating { get; set; }
    public int? TmdbVotes { get; set; }
    public double? ImdbRating { get; set; }
    public long? ImdbVotes { get; set; }
    public double? RottenTomatoesRating { get; set; }

    public MediaRatingsDto() {}

    public MediaRatingsDto(MediaRatings ratings)
    {
        TmdbRating = ratings.TmdbRating;
        TmdbVotes = ratings.TmdbVotes;
        ImdbRating = ratings.ImdbRating;
        ImdbVotes = ratings.ImdbVotes;
        RottenTomatoesRating = ratings.RottenTomatoesRating;
    }
}
