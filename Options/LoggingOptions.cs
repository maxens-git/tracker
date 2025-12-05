namespace Tracker.Options;

public class LoggingOptions
{
    public const string SectionName = "Logging";

    public LogLevelOptions LogLevel { get; set; } = new();
}

public class LogLevelOptions
{
    public string Default { get; set; } = "Information";
    public string MicrosoftAspNetCore { get; set; } = "Warning";
}
