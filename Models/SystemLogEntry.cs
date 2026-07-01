using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.Extensions.Logging;

namespace Tracker.Models;

[Table("SystemLogEntries")]
public class SystemLogEntry
{
    [Key]
    public int Id { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public LogLevel Level { get; set; }

    [MaxLength(300)]
    public string Category { get; set; } = "";

    [MaxLength(4000)]
    public string Message { get; set; } = "";

    public string? Exception { get; set; }

    public int EventId { get; set; }

    [MaxLength(100)]
    public string? TraceId { get; set; }

    [MaxLength(12)]
    public string? Method { get; set; }

    [MaxLength(1000)]
    public string? Path { get; set; }

    public int? StatusCode { get; set; }

    public double? ElapsedMs { get; set; }
}
