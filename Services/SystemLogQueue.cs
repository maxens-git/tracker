using System.Threading.Channels;
using Microsoft.Extensions.Logging;

namespace Tracker.Services;

public record SystemLogWrite(
    DateTime CreatedAt,
    LogLevel Level,
    string Category,
    string Message,
    string? Exception,
    int EventId,
    string? TraceId,
    string? Method,
    string? Path,
    int? StatusCode,
    double? ElapsedMs);

public class SystemLogQueue
{
    private readonly Channel<SystemLogWrite> channel = Channel.CreateBounded<SystemLogWrite>(
        new BoundedChannelOptions(2000)
        {
            FullMode = BoundedChannelFullMode.DropOldest,
            SingleReader = true,
            SingleWriter = false,
        });

    public bool TryWrite(SystemLogWrite log) => channel.Writer.TryWrite(log);

    public ValueTask<SystemLogWrite> ReadAsync(CancellationToken cancellationToken) =>
        channel.Reader.ReadAsync(cancellationToken);

    public bool TryRead(out SystemLogWrite log) => channel.Reader.TryRead(out log!);
}
