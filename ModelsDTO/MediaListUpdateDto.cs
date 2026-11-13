using System.ComponentModel.DataAnnotations;

namespace Tracker.ModelsDTO;

public class MediaListUpdateDto
{
    [MaxLength(100)]
    public string? Name { get; set; }
    [MaxLength(500)]
    public string? Description { get; set; }
}
