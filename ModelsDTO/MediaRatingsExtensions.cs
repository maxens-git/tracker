using Tracker.Models;

namespace Tracker.ModelsDTO;

public static class MediaRatingsExtensions
{
    public static MediaRatingsDto ToDto(this MediaRatings ratings)
    {
        return new MediaRatingsDto
        {
            TmdbRating = ratings?.TmdbRating,
            TmdbVotes = ratings?.TmdbVotes,
            ImdbRating = ratings?.ImdbRating,
            ImdbVotes = ratings?.ImdbVotes,
            RottenTomatoesRating = ratings?.RottenTomatoesRating
        };
    }
}
