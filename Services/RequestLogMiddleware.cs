using System.Diagnostics;
using Microsoft.Extensions.Logging;

namespace Tracker.Services;

public class RequestLogMiddleware(RequestDelegate next, SystemLogQueue queue)
{
    public async Task Invoke(HttpContext context)
    {
        PathString path = context.Request.Path;
        if (!path.StartsWithSegments("/api") || path.StartsWithSegments("/api/logs"))
        {
            await next(context);
            return;
        }

        Stopwatch stopwatch = Stopwatch.StartNew();
        bool failedWithException = false;

        try
        {
            await next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            failedWithException = true;
            stopwatch.Stop();
            Enqueue(context, LogLevel.Information, "API request cancelled", null, stopwatch.Elapsed.TotalMilliseconds, 499);
            throw;
        }
        catch (Exception ex)
        {
            failedWithException = true;
            stopwatch.Stop();
            Enqueue(context, LogLevel.Error, "Unhandled API exception", ex, stopwatch.Elapsed.TotalMilliseconds);
            throw;
        }
        finally
        {
            stopwatch.Stop();

            if (!failedWithException)
            {
                if (context.Response.StatusCode >= 400)
                {
                    Enqueue(
                        context,
                        context.Response.StatusCode >= 500 ? LogLevel.Error : LogLevel.Warning,
                        "API request failed",
                        null,
                        stopwatch.Elapsed.TotalMilliseconds);
                }
                else
                {
                    Enqueue(context, LogLevel.Information, "API request completed", null, stopwatch.Elapsed.TotalMilliseconds);
                }
            }
        }
    }

    private void Enqueue(HttpContext context, LogLevel level, string message, Exception? exception, double elapsedMs, int? statusCode = null)
    {
        queue.TryWrite(new SystemLogWrite(
            DateTime.UtcNow,
            level,
            "Tracker.Http",
            message,
            exception?.ToString(),
            0,
            Limit(context.TraceIdentifier, 100),
            Limit(context.Request.Method, 12),
            Limit(context.Request.Path.Value, 1000),
            statusCode ?? (exception != null && !context.Response.HasStarted
                ? StatusCodes.Status500InternalServerError
                : context.Response.StatusCode),
            Math.Round(elapsedMs, 1)));
    }

    private static string? Limit(string? value, int length) =>
        value?.Length > length ? value[..length] : value;
}
