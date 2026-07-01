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

    private void Enqueue(HttpContext context, LogLevel level, string message, Exception? exception, double elapsedMs)
    {
        queue.TryWrite(new SystemLogWrite(
            DateTime.UtcNow,
            level,
            "Tracker.Http",
            message,
            exception?.ToString(),
            0,
            context.TraceIdentifier,
            context.Request.Method,
            context.Request.Path.Value,
            context.Response.StatusCode,
            Math.Round(elapsedMs, 1)));
    }
}
