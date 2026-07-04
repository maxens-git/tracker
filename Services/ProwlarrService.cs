using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.ModelsDTO;

namespace Tracker.Services;

/// <summary>
/// Interroge Prowlarr (agrégateur d'indexeurs) et ne remonte que les torrents
/// exploitables par AllDebrid : protocole « torrent » avec un magnet disponible.
/// L'URL et la clé sont lues dans les réglages (table Settings) à chaque appel.
/// </summary>
public class ProwlarrService(HttpClient http, ApiDbContext context, ILogger<ProwlarrService> logger)
{
    /// <summary>Liste les indexeurs torrent activés dans Prowlarr, pour permettre le filtrage.</summary>
    public async Task<List<IndexerDto>> GetIndexers(CancellationToken cancellationToken)
    {
        using JsonDocument doc = await GetJson("/api/v1/indexer", cancellationToken);

        var indexers = new List<IndexerDto>();
        foreach (JsonElement item in doc.RootElement.EnumerateArray())
        {
            if (!IsEnabledTorrentIndexer(item)) continue;

            if (item.TryGetProperty("id", out JsonElement idEl) && idEl.ValueKind == JsonValueKind.Number)
                indexers.Add(new IndexerDto(idEl.GetInt32(), ReadString(item, "name") ?? $"Indexeur {idEl.GetInt32()}"));
        }

        indexers.Sort((a, b) => string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase));
        return indexers;
    }

    /// <summary>
    /// Liste les catégories de recherche (Torznab) supportées par les indexeurs torrent,
    /// agrégées depuis leurs « capabilities », dédupliquées et triées par id.
    /// </summary>
    public async Task<List<CategoryDto>> GetCategories(CancellationToken cancellationToken)
    {
        using JsonDocument doc = await GetJson("/api/v1/indexer", cancellationToken);

        var categories = new Dictionary<int, string>();
        foreach (JsonElement item in doc.RootElement.EnumerateArray())
        {
            if (!IsEnabledTorrentIndexer(item)) continue;

            if (!item.TryGetProperty("capabilities", out JsonElement caps) ||
                !caps.TryGetProperty("categories", out JsonElement cats) ||
                cats.ValueKind != JsonValueKind.Array)
                continue;

            foreach (JsonElement cat in cats.EnumerateArray())
            {
                if (cat.TryGetProperty("id", out JsonElement idEl) && idEl.ValueKind == JsonValueKind.Number)
                    categories[idEl.GetInt32()] = ReadString(cat, "name") ?? $"Catégorie {idEl.GetInt32()}";
            }
        }

        return categories
            .OrderBy(kv => kv.Key)
            .Select(kv => new CategoryDto(kv.Key, kv.Value))
            .ToList();
    }

    public async Task<List<TorrentResultDto>> Search(string query, IReadOnlyList<int>? indexerIds, int? categoryId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(query))
            return [];

        string path = $"/api/v1/search?query={Uri.EscapeDataString(query)}&type=search";
        if (indexerIds is { Count: > 0 })
            foreach (int id in indexerIds)
                path += $"&indexerIds={id}";
        if (categoryId is int cat) path += $"&categories={cat}";

        logger.LogInformation("Recherche Prowlarr: {Query} (indexeurs: {Indexers}, catégorie: {Category})",
            query, indexerIds is { Count: > 0 } ? string.Join(",", indexerIds) : "tous", categoryId?.ToString() ?? "toutes");

        using JsonDocument doc = await GetJson(path, cancellationToken);

        int total = 0, torrents = 0, withMagnet = 0, withHash = 0;
        var results = new List<TorrentResultDto>();
        foreach (JsonElement item in doc.RootElement.EnumerateArray())
        {
            total++;
            // Prowlarr sérialise le protocole en chaîne (« torrent »/« usenet ») ; on reste tolérant à la casse.
            if (!string.Equals(ReadString(item, "protocol"), "torrent", StringComparison.OrdinalIgnoreCase)) continue;
            torrents++;

            string title = ReadString(item, "title") ?? "Sans titre";
            string? magnet = ResolveMagnet(item, title, ref withMagnet, ref withHash);
            if (magnet is null) continue;

            results.Add(new TorrentResultDto(
                Title: title,
                Size: ReadLong(item, "size"),
                Seeders: ReadInt(item, "seeders"),
                Leechers: ReadInt(item, "leechers"),
                Indexer: ReadString(item, "indexer") ?? "?",
                MagnetUrl: magnet));
        }

        results.Sort((a, b) => b.Seeders.CompareTo(a.Seeders));
        logger.LogInformation(
            "Prowlarr « {Query} »: {Total} résultat(s), {Torrents} torrent(s), {Magnet} avec magnetUrl, {Hash} via infoHash → {Kept} exploitable(s).",
            query, total, torrents, withMagnet, withHash, results.Count);
        return results;
    }

    /// <summary>
    /// Renvoie un magnet exploitable par AllDebrid : le magnetUrl s'il existe, sinon un magnet
    /// reconstruit depuis l'infoHash (fréquent quand magnetUrl est absent), ou null si aucun.
    /// </summary>
    private static string? ResolveMagnet(JsonElement item, string title, ref int withMagnet, ref int withHash)
    {
        string? magnet = ReadString(item, "magnetUrl");
        if (!string.IsNullOrWhiteSpace(magnet))
        {
            withMagnet++;
            return magnet;
        }

        string? hash = ReadString(item, "infoHash");
        if (!string.IsNullOrWhiteSpace(hash))
        {
            withHash++;
            return $"magnet:?xt=urn:btih:{hash}&dn={Uri.EscapeDataString(title)}";
        }

        return null;
    }

    private static bool IsEnabledTorrentIndexer(JsonElement item)
    {
        bool enabled = item.TryGetProperty("enable", out JsonElement e) && e.ValueKind == JsonValueKind.True;
        return enabled && string.Equals(ReadString(item, "protocol"), "torrent", StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>GET authentifié vers Prowlarr renvoyant le JSON parsé (à disposer par l'appelant).</summary>
    private async Task<JsonDocument> GetJson(string path, CancellationToken cancellationToken)
    {
        (string baseUrl, string apiKey) = await GetCredentials(cancellationToken);

        using HttpRequestMessage request = new(HttpMethod.Get, $"{baseUrl}{path}");
        request.Headers.Add("X-Api-Key", apiKey);

        using HttpResponseMessage response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        await using Stream stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        return await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
    }

    private async Task<(string baseUrl, string apiKey)> GetCredentials(CancellationToken cancellationToken)
    {
        var settings = await context.Settings.AsNoTracking().FirstOrDefaultAsync(s => s.Id == 1, cancellationToken);

        if (string.IsNullOrWhiteSpace(settings?.ProwlarrUrl) || string.IsNullOrWhiteSpace(settings.ProwlarrApiKey))
            throw new InvalidOperationException("Prowlarr n'est pas configuré (URL ou clé API manquante).");

        return (settings.ProwlarrUrl.TrimEnd('/'), settings.ProwlarrApiKey);
    }

    private static string? ReadString(JsonElement element, string name) =>
        element.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static int ReadInt(JsonElement element, string name) =>
        element.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.Number
            ? value.GetInt32()
            : 0;

    private static long ReadLong(JsonElement element, string name) =>
        element.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.Number
            ? value.GetInt64()
            : 0;
}
