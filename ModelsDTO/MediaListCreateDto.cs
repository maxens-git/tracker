using System.ComponentModel.DataAnnotations;

namespace Tracker.ModelsDTO;

public class MediaListCreateDto
{
    [Required, MaxLength(100)]
    public string Name { get; set; } = string.Empty;
    [MaxLength(500)]
    public string? Description { get; set; }
}
