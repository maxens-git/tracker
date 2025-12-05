namespace Tracker.Options;

public class JustWatchOptions
{
    public const string SectionName = "JustWatch";

    public bool EnableImport { get; set; } = false;
    public string ExportFilePath { get; set; } = string.Empty;
}
