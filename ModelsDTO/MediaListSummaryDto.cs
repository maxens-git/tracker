using Tracker.Models;

namespace Tracker.ModelsDTO;

public class MediaListSummaryDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Icon { get; set; }
    public bool IsSystem { get; set; }
    public int ItemsCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }

    public MediaListSummaryDto(MediaList ml, int itemsCount)
    {
        Id = ml.Id;
        Name = ml.Name;
        Description = ml.Description;
        Icon = ml.Icon;
        IsSystem = ml.IsSystem;
        ItemsCount = itemsCount;
        CreatedAt = ml.AddedAt;
        UpdatedAt = ml.UpdatedAt;
    }
}
