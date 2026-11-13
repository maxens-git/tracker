using Tracker.Models;

namespace Tracker.ModelsDTO;

/// <summary>
/// Sauvegarde complète de la base : une liste par table, identifiants conservés pour que les
/// références croisées (visionnages → média, items → liste, activité → liste) restent valides.
/// </summary>
public class DatabaseBackup
{
    public const string FormatName = "tracker-backup";
    public const int CurrentVersion = 1;

    public string Format { get; set; } = FormatName;
    public int Version { get; set; } = CurrentVersion;
    public DateTime ExportedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Dernière migration EF appliquée au moment de l'export (informatif).</summary>
    public string? SchemaMigration { get; set; }

    public List<AppSettings> Settings { get; set; } = new();
    public List<UserMedia> UserMedia { get; set; } = new();
    public List<UserMediaWatchEvent> UserMediaWatchEvents { get; set; } = new();
    public List<UserEpisode> UserEpisodes { get; set; } = new();
    public List<UserEpisodeWatchEvent> UserEpisodeWatchEvents { get; set; } = new();
    public List<MediaList> MediaLists { get; set; } = new();
    public List<MediaListItem> MediaListItems { get; set; } = new();
    public List<ActivityEvent> ActivityEvents { get; set; } = new();
    public List<TrackedMediaRelease> TrackedMediaReleases { get; set; } = new();
    public List<ReleaseNotification> ReleaseNotifications { get; set; } = new();
    public List<KnownSeason> KnownSeasons { get; set; } = new();
    public List<TorrentBookmark> TorrentBookmarks { get; set; } = new();
    public List<FavoriteTheater> FavoriteTheaters { get; set; } = new();

    /// <summary>Null si les logs n'ont pas été exportés : l'import conserve alors les logs existants.</summary>
    public List<SystemLogEntry>? SystemLogEntries { get; set; }
}

/// <summary>Nombre de lignes importées par table.</summary>
public record BackupImportResult(DateTime ExportedAt, IReadOnlyDictionary<string, int> Counts);
