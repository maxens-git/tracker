using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("MediaLists")]
public class MediaList
{
    public MediaList(string name, string? description = null, string? icon = null, bool isSystem = false)
    {
        Name = name;
        Description = description;
        Icon = icon;
        IsSystem = isSystem;
    }

    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Description { get; set; }

    [MaxLength(50)]
    public string? Icon { get; set; }

    public bool IsSystem { get; set; } = false;

    public DateTime AddedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }

    public List<MediaListItem> Items { get; set; } = new();
}
