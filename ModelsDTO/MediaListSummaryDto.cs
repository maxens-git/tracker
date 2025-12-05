namespace Tracker.ModelsDTO;

public class MediaListSummaryDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Icon { get; set; }
    public bool IsSystem { get; set; }
    public int MoviesCount { get; set; }
    public int ShowsCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
