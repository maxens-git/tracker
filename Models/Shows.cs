
namespace Tracker.Models;

[Table("Shows")]
public class Show : BaseMedia
{
    public int NumberOfSeasons { get; set; }
    public int NumberOfEpisodes { get; set; }
    
    public DateTime? LastAirDate { get; set; }

    public List<Season> Seasons { get; set; } = new();
}