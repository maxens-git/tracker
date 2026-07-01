using Tracker.Models;

namespace Tracker.ModelsDTO;

public class SystemLogDto
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; }
    public string Level { get; set; } = "";
    public string Category { get; set; } = "";
    public string Message { get; set; } = "";
    public string? Exception { get; set; }
    public int EventId { get; set; }
    public string? TraceId { get; set; }
    public string? Method { get; set; }
    public string? Path { get; set; }
    public int? StatusCode { get; set; }
    public double? ElapsedMs { get; set; }

    public SystemLogDto(SystemLogEntry log)
    {
        Id = log.Id;
        CreatedAt = log.CreatedAt;
        Level = log.Level.ToString();
        Category = log.Category;
        Message = log.Message;
        Exception = log.Exception;
        EventId = log.EventId;
        TraceId = log.TraceId;
        Method = log.Method;
        Path = log.Path;
        StatusCode = log.StatusCode;
        ElapsedMs = log.ElapsedMs;
    }
}
