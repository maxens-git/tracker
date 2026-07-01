using Microsoft.Extensions.Logging;

namespace Tracker.Services;

public class DatabaseLoggerProvider(SystemLogQueue queue, IHttpContextAccessor httpContextAccessor) : ILoggerProvider
{
    public ILogger CreateLogger(string categoryName) =>
        new DatabaseLogger(categoryName, queue, httpContextAccessor);

    public void Dispose()
    {
    }
}

internal class DatabaseLogger(
    string category,
    SystemLogQueue queue,
    IHttpContextAccessor httpContextAccessor) : ILogger
{
    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

    public bool IsEnabled(LogLevel logLevel)
    {
        if (logLevel < LogLevel.Information || logLevel == LogLevel.None)
            return false;

        if (category.StartsWith("Microsoft.EntityFrameworkCore", StringComparison.Ordinal))
            return false;

        if (category.StartsWith("Tracker.Services.SystemLog", StringComparison.Ordinal))
            return false;

        return category.StartsWith("Tracker.", StringComparison.Ordinal) || logLevel >= LogLevel.Warning;
    }

    public void Log<TState>(
        LogLevel logLevel,
        EventId eventId,
        TState state,
        Exception? exception,
        Func<TState, Exception?, string> formatter)
    {
        if (!IsEnabled(logLevel))
            return;

        string message = formatter(state, exception);
        if (string.IsNullOrWhiteSpace(message) && exception == null)
            return;

        HttpContext? context = httpContextAccessor.HttpContext;
        queue.TryWrite(new SystemLogWrite(
            DateTime.UtcNow,
            logLevel,
            Limit(category, 300),
            Limit(message, 4000),
            exception?.ToString(),
            eventId.Id,
            LimitNullable(context?.TraceIdentifier, 100),
            LimitNullable(context?.Request.Method, 12),
            LimitNullable(context?.Request.Path.Value, 1000),
            context?.Response.StatusCode,
            null));
    }

    private static string Limit(string value, int maxLength) =>
        value.Length <= maxLength ? value : value[..maxLength];

    private static string? LimitNullable(string? value, int maxLength) =>
        string.IsNullOrEmpty(value) || value.Length <= maxLength ? value : value[..maxLength];
}
