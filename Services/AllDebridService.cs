using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Tracker.Data;
using Tracker.ModelsDTO;

namespace Tracker.Services;

/// <summary>
/// Débride un magnet via AllDebrid, uniquement si le torrent est déjà en cache
/// (champ « ready » renvoyé par magnet/upload). Sinon le magnet est supprimé
/// aussitôt pour ne pas déclencher de téléchargement côté AllDebrid.
/// La clé API est lue dans les réglages (table Settings) à chaque appel.
/// </summary>
public class AllDebridService(HttpClient http, ApiDbContext context, ILogger<AllDebridService> logger)
{
    private const string BaseUrl = "https://api.alldebrid.com/v4";

    /// <summary>Levée quand le torrent n'est pas en cache : rien à débrider.</summary>
    public class NotCachedException() : Exception("Ce torrent n'est pas en cache sur AllDebrid.");

    public async Task<DebridResultDto> Debrid(string magnet, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(magnet))
            throw new InvalidOperationException("Magnet vide.");

        string apiKey = await GetApiKey(cancellationToken);

        // 1. Upload du magnet → on lit id + ready (cache ou non).
        JsonElement uploadData = await PostForm(apiKey, "magnet/upload",
            [new("magnets[]", magnet)], cancellationToken);

        if (!uploadData.TryGetProperty("magnets", out JsonElement magnets) || magnets.GetArrayLength() == 0)
            throw new InvalidOperationException("Réponse AllDebrid inattendue : aucun magnet renvoyé.");

        JsonElement uploaded = magnets[0];

        // AllDebrid peut renvoyer une erreur propre à ce magnet (ex. magnet invalide).
        if (uploaded.TryGetProperty("error", out JsonElement magnetError))
            throw new InvalidOperationException(
                magnetError.TryGetProperty("message", out JsonElement msg) ? msg.GetString() ?? "Magnet refusé par AllDebrid." : "Magnet refusé par AllDebrid.");

        long id = uploaded.GetProperty("id").GetInt64();
        bool ready = uploaded.TryGetProperty("ready", out JsonElement r) && r.ValueKind == JsonValueKind.True;

        if (!ready)
        {
            // Pas en cache : on nettoie pour ne pas lancer de téléchargement.
            await TryDelete(apiKey, id, cancellationToken);
            logger.LogInformation("Débridage refusé (non caché) pour le magnet id {Id}.", id);
            throw new NotCachedException();
        }

        // 2. Récupération de l'arbre de fichiers du magnet (sans générer les liens directs :
        //    ils ne seront débridés qu'à la demande, un par un, via Unlock).
        JsonElement filesData = await PostForm(apiKey, "magnet/files",
            [new("id[]", id.ToString())], cancellationToken);

        var files = new List<DebridFileDto>();
        foreach (JsonElement magnetNode in filesData.GetProperty("magnets").EnumerateArray())
            if (magnetNode.TryGetProperty("files", out JsonElement tree))
                CollectFiles(tree, files);

        logger.LogInformation("Torrent débridé (id {Id}): {Count} fichier(s) listé(s).", id, files.Count);
        return new DebridResultDto(files);
    }

    /// <summary>Débride un seul lien AllDebrid verrouillé → lien de téléchargement direct.</summary>
    public async Task<UnlockResultDto> Unlock(string link, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(link))
            throw new InvalidOperationException("Lien vide.");

        string apiKey = await GetApiKey(cancellationToken);

        JsonElement unlocked = await PostForm(apiKey, "link/unlock",
            [new("link", link)], cancellationToken);

        // Un lien « delayed » n'est pas immédiatement prêt (rare pour un torrent en cache).
        if (unlocked.TryGetProperty("link", out JsonElement direct) && direct.ValueKind == JsonValueKind.String)
            return new UnlockResultDto(direct.GetString()!);

        throw new InvalidOperationException("Lien de téléchargement indisponible pour ce fichier.");
    }

    /// <summary>Parcourt récursivement l'arbre AllDebrid (fichiers « l » avec nom « n »/taille « s », dossiers « e »).</summary>
    private static void CollectFiles(JsonElement node, List<DebridFileDto> files)
    {
        foreach (JsonElement entry in node.EnumerateArray())
        {
            if (entry.TryGetProperty("l", out JsonElement link) && link.ValueKind == JsonValueKind.String)
            {
                files.Add(new DebridFileDto(
                    Filename: entry.TryGetProperty("n", out JsonElement n) ? n.GetString() ?? "" : "",
                    Size: entry.TryGetProperty("s", out JsonElement s) && s.ValueKind == JsonValueKind.Number ? s.GetInt64() : 0,
                    Link: link.GetString()!));
            }
            else if (entry.TryGetProperty("e", out JsonElement children) && children.ValueKind == JsonValueKind.Array)
            {
                CollectFiles(children, files);
            }
        }
    }

    private async Task<string> GetApiKey(CancellationToken cancellationToken)
    {
        var settings = await context.Settings.AsNoTracking().FirstOrDefaultAsync(s => s.Id == 1, cancellationToken);
        if (string.IsNullOrWhiteSpace(settings?.AllDebridApiKey))
            throw new InvalidOperationException("AllDebrid n'est pas configuré (clé API manquante).");
        return settings.AllDebridApiKey;
    }

    private async Task TryDelete(string apiKey, long id, CancellationToken cancellationToken)
    {
        try
        {
            await PostForm(apiKey, "magnet/delete", [new("id", id.ToString())], cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Suppression du magnet non caché id {Id} échouée.", id);
        }
    }

    /// <summary>POST form-urlencoded vers AllDebrid, renvoie le nœud « data » ou lève sur erreur applicative.</summary>
    private async Task<JsonElement> PostForm(
        string apiKey,
        string path,
        IEnumerable<KeyValuePair<string, string>> fields,
        CancellationToken cancellationToken)
    {
        using HttpRequestMessage request = new(HttpMethod.Post, $"{BaseUrl}/{path}")
        {
            Content = new FormUrlEncodedContent(fields),
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);

        using HttpResponseMessage response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        using JsonDocument doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
        JsonElement root = doc.RootElement;

        if (root.TryGetProperty("status", out JsonElement status) && status.GetString() == "error")
        {
            string message = root.TryGetProperty("error", out JsonElement err) && err.TryGetProperty("message", out JsonElement m)
                ? m.GetString() ?? "Erreur AllDebrid"
                : "Erreur AllDebrid";
            throw new InvalidOperationException($"AllDebrid ({path}): {message}");
        }

        // On clone pour que le JsonElement reste valide après dispose du JsonDocument.
        return root.GetProperty("data").Clone();
    }
}
