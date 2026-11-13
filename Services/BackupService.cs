using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Services;

/// <summary>Données de sauvegarde invalides (format inconnu, références cassées...).</summary>
public class BackupValidationException(string message) : Exception(message);

/// <summary>
/// Export / import complet de la base. L'import remplace tout le contenu dans une seule
/// transaction : en cas d'erreur, la base reste dans son état d'avant.
/// </summary>
public class BackupService(ApiDbContext context, ILogger<BackupService> logger)
{
    /// <summary>
    /// Sérialisation dédiée : camelCase, enums lisibles, et sans les propriétés de navigation
    /// (chaque table est exportée à plat, les liens passent par les clés étrangères).
    /// </summary>
    public static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() },
        TypeInfoResolver = new DefaultJsonTypeInfoResolver
        {
            Modifiers = { RemoveNavigationProperties },
        },
    };

    public async Task<DatabaseBackup> Export(bool includeLogs, CancellationToken cancellationToken)
    {
        IEnumerable<string> applied = await context.Database.GetAppliedMigrationsAsync(cancellationToken);

        return new DatabaseBackup
        {
            ExportedAt = DateTime.UtcNow,
            SchemaMigration = applied.LastOrDefault(),
            Settings = await context.Settings.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            UserMedia = await context.UserMedia.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            UserMediaWatchEvents = await context.UserMediaWatchEvents.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            UserEpisodes = await context.UserEpisodes.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            UserEpisodeWatchEvents = await context.UserEpisodeWatchEvents.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            MediaLists = await context.MediaLists.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            MediaListItems = await context.MediaListItems.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            ActivityEvents = await context.ActivityEvents.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            TrackedMediaReleases = await context.TrackedMediaReleases.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            ReleaseNotifications = await context.ReleaseNotifications.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            KnownSeasons = await context.KnownSeasons.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            TorrentBookmarks = await context.TorrentBookmarks.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            FavoriteTheaters = await context.FavoriteTheaters.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken),
            SystemLogEntries = includeLogs
                ? await context.SystemLogEntries.AsNoTracking().OrderBy(e => e.Id).ToListAsync(cancellationToken)
                : null,
        };
    }

    public async Task<DatabaseBackup> Read(Stream stream, CancellationToken cancellationToken)
    {
        DatabaseBackup? backup;
        try
        {
            backup = await JsonSerializer.DeserializeAsync<DatabaseBackup>(stream, JsonOptions, cancellationToken);
        }
        catch (JsonException ex)
        {
            throw new BackupValidationException($"Fichier de sauvegarde illisible : {ex.Message}");
        }

        if (backup == null)
            throw new BackupValidationException("Fichier de sauvegarde vide.");

        return backup;
    }

    public async Task<BackupImportResult> Import(DatabaseBackup backup, CancellationToken cancellationToken)
    {
        Validate(backup);
        bool replaceLogs = backup.SystemLogEntries != null;

        // Les logs ne sont référencés par rien : on laisse MySQL renuméroter pour ne pas
        // entrer en collision avec ceux écrits en parallèle par SystemLogWriterService.
        foreach (SystemLogEntry log in backup.SystemLogEntries ?? [])
            log.Id = 0;

        // EnableRetryOnFailure impose de passer par la stratégie d'exécution pour une transaction manuelle.
        IExecutionStrategy strategy = context.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(async () =>
        {
            context.ChangeTracker.Clear();
            await using var transaction = await context.Database.BeginTransactionAsync(cancellationToken);

            // Enfants d'abord pour respecter les clés étrangères.
            await context.UserMediaWatchEvents.ExecuteDeleteAsync(cancellationToken);
            await context.UserEpisodeWatchEvents.ExecuteDeleteAsync(cancellationToken);
            await context.MediaListItems.ExecuteDeleteAsync(cancellationToken);
            await context.UserMedia.ExecuteDeleteAsync(cancellationToken);
            await context.UserEpisodes.ExecuteDeleteAsync(cancellationToken);
            await context.MediaLists.ExecuteDeleteAsync(cancellationToken);
            await context.ActivityEvents.ExecuteDeleteAsync(cancellationToken);
            await context.TrackedMediaReleases.ExecuteDeleteAsync(cancellationToken);
            await context.ReleaseNotifications.ExecuteDeleteAsync(cancellationToken);
            await context.KnownSeasons.ExecuteDeleteAsync(cancellationToken);
            await context.TorrentBookmarks.ExecuteDeleteAsync(cancellationToken);
            await context.FavoriteTheaters.ExecuteDeleteAsync(cancellationToken);
            await context.Settings.ExecuteDeleteAsync(cancellationToken);
            if (replaceLogs)
                await context.SystemLogEntries.ExecuteDeleteAsync(cancellationToken);

            context.Settings.AddRange(backup.Settings);
            context.UserMedia.AddRange(backup.UserMedia);
            context.UserMediaWatchEvents.AddRange(backup.UserMediaWatchEvents);
            context.UserEpisodes.AddRange(backup.UserEpisodes);
            context.UserEpisodeWatchEvents.AddRange(backup.UserEpisodeWatchEvents);
            context.MediaLists.AddRange(backup.MediaLists);
            context.MediaListItems.AddRange(backup.MediaListItems);
            context.ActivityEvents.AddRange(backup.ActivityEvents);
            context.TrackedMediaReleases.AddRange(backup.TrackedMediaReleases);
            context.ReleaseNotifications.AddRange(backup.ReleaseNotifications);
            context.KnownSeasons.AddRange(backup.KnownSeasons);
            context.TorrentBookmarks.AddRange(backup.TorrentBookmarks);
            context.FavoriteTheaters.AddRange(backup.FavoriteTheaters);
            if (replaceLogs)
                context.SystemLogEntries.AddRange(backup.SystemLogEntries!);

            try
            {
                await context.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException ex)
            {
                throw new BackupValidationException(
                    $"Import refusé par la base : {ex.InnerException?.Message ?? ex.Message}");
            }

            await transaction.CommitAsync(cancellationToken);
        });

        context.ChangeTracker.Clear();
        // Une sauvegarde ancienne ou éditée à la main peut ne pas contenir toutes les listes système.
        await DbSeeder.SeedSystemListsAsync(context);

        Dictionary<string, int> counts = new()
        {
            ["settings"] = backup.Settings.Count,
            ["userMedia"] = backup.UserMedia.Count,
            ["userMediaWatchEvents"] = backup.UserMediaWatchEvents.Count,
            ["userEpisodes"] = backup.UserEpisodes.Count,
            ["userEpisodeWatchEvents"] = backup.UserEpisodeWatchEvents.Count,
            ["mediaLists"] = backup.MediaLists.Count,
            ["mediaListItems"] = backup.MediaListItems.Count,
            ["activityEvents"] = backup.ActivityEvents.Count,
            ["trackedMediaReleases"] = backup.TrackedMediaReleases.Count,
            ["releaseNotifications"] = backup.ReleaseNotifications.Count,
            ["knownSeasons"] = backup.KnownSeasons.Count,
            ["torrentBookmarks"] = backup.TorrentBookmarks.Count,
            ["favoriteTheaters"] = backup.FavoriteTheaters.Count,
        };
        if (replaceLogs)
            counts["systemLogEntries"] = backup.SystemLogEntries!.Count;

        logger.LogWarning(
            "Base remplacée par une sauvegarde du {ExportedAt:u} : {Media} médias, {Lists} listes, {Items} items, logs {Logs}.",
            backup.ExportedAt,
            backup.UserMedia.Count,
            backup.MediaLists.Count,
            backup.MediaListItems.Count,
            replaceLogs ? "remplacés" : "conservés");

        return new BackupImportResult(backup.ExportedAt, counts);
    }

    /// <summary>
    /// Vérifie le format et les références internes avant de toucher à la base, pour renvoyer
    /// une erreur claire plutôt qu'une violation de clé étrangère MySQL.
    /// </summary>
    private static void Validate(DatabaseBackup backup)
    {
        if (backup.Format != DatabaseBackup.FormatName)
            throw new BackupValidationException("Ce fichier n'est pas une sauvegarde Tracker.");

        if (backup.Version > DatabaseBackup.CurrentVersion)
            throw new BackupValidationException(
                $"Sauvegarde en version {backup.Version}, cette version de l'application ne gère que la version {DatabaseBackup.CurrentVersion}.");

        HashSet<int> mediaIds = backup.UserMedia.Select(m => m.Id).ToHashSet();
        HashSet<int> episodeIds = backup.UserEpisodes.Select(e => e.Id).ToHashSet();
        HashSet<int> listIds = backup.MediaLists.Select(l => l.Id).ToHashSet();

        if (backup.UserMediaWatchEvents.FirstOrDefault(w => !mediaIds.Contains(w.UserMediaId)) is { } orphanMediaWatch)
            throw new BackupValidationException($"Visionnage {orphanMediaWatch.Id} rattaché à un média inexistant ({orphanMediaWatch.UserMediaId}).");

        if (backup.UserEpisodeWatchEvents.FirstOrDefault(w => !episodeIds.Contains(w.UserEpisodeId)) is { } orphanEpisodeWatch)
            throw new BackupValidationException($"Visionnage d'épisode {orphanEpisodeWatch.Id} rattaché à un épisode inexistant ({orphanEpisodeWatch.UserEpisodeId}).");

        if (backup.MediaListItems.FirstOrDefault(i => !listIds.Contains(i.MediaListId)) is { } orphanItem)
            throw new BackupValidationException($"Item {orphanItem.Id} rattaché à une liste inexistante ({orphanItem.MediaListId}).");
    }

    private static void RemoveNavigationProperties(JsonTypeInfo typeInfo)
    {
        if (typeInfo.Kind != JsonTypeInfoKind.Object || typeInfo.Type.Namespace != typeof(UserMedia).Namespace)
            return;

        for (int i = typeInfo.Properties.Count - 1; i >= 0; i--)
        {
            Type type = typeInfo.Properties[i].PropertyType;
            Type? element = type.IsGenericType && type.GetGenericTypeDefinition() == typeof(List<>)
                ? type.GetGenericArguments()[0]
                : null;

            if (IsEntity(type) || (element != null && IsEntity(element)))
                typeInfo.Properties.RemoveAt(i);
        }
    }

    private static bool IsEntity(Type type) =>
        type.IsClass && type != typeof(string) && type.Namespace == typeof(UserMedia).Namespace;
}
