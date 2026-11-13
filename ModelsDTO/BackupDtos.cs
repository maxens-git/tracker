using System.Text.Json.Serialization;
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

    [JsonRequired]
    public string Format { get; set; } = FormatName;
    [JsonRequired]
    public int Version { get; set; } = CurrentVersion;
    public DateTime ExportedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Dernière migration EF appliquée au moment de l'export (informatif).</summary>
    public string? SchemaMigration { get; set; }

    [JsonRequired]
    public List<AppSettings> Settings { get; set; } = new();
    [JsonRequired]
    public List<UserMedia> UserMedia { get; set; } = new();
    [JsonRequired]
    public List<UserMediaWatchEvent> UserMediaWatchEvents { get; set; } = new();
    [JsonRequired]
    public List<UserEpisode> UserEpisodes { get; set; } = new();
    [JsonRequired]
    public List<UserEpisodeWatchEvent> UserEpisodeWatchEvents { get; set; } = new();
    [JsonRequired]
    public List<MediaList> MediaLists { get; set; } = new();
    [JsonRequired]
    public List<MediaListItem> MediaListItems { get; set; } = new();
    [JsonRequired]
    public List<ActivityEvent> ActivityEvents { get; set; } = new();
    [JsonRequired]
    public List<TrackedMediaRelease> TrackedMediaReleases { get; set; } = new();
    [JsonRequired]
    public List<ReleaseNotification> ReleaseNotifications { get; set; } = new();
    [JsonRequired]
    public List<KnownSeason> KnownSeasons { get; set; } = new();
    [JsonRequired]
    public List<TorrentBookmark> TorrentBookmarks { get; set; } = new();
    [JsonRequired]
    public List<FavoriteTheater> FavoriteTheaters { get; set; } = new();

    /// <summary>Null si les logs n'ont pas été exportés : l'import conserve alors les logs existants.</summary>
    public List<SystemLogEntry>? SystemLogEntries { get; set; }
}

/// <summary>Nombre de lignes importées par table.</summary>
public record BackupImportResult(DateTime ExportedAt, IReadOnlyDictionary<string, int> Counts);
