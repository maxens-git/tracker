using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.EntityFrameworkCore;
using MySqlConnector;
using Tracker.Data;
using Tracker.Models;
using Tracker.ModelsDTO;

namespace Tracker.Controllers;

/// <summary>
/// Marque-pages torrents : mettre un magnet de côté pour le télécharger plus tard.
/// Indépendant de la watchlist et des listes.
/// </summary>
[ApiController]
[Route("api/torrent-bookmarks")]
public class TorrentBookmarksController(ApiDbContext context) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IEnumerable<TorrentBookmarkDto>>> GetAll()
    {
        List<TorrentBookmark> bookmarks = await context.TorrentBookmarks
            .OrderByDescending(b => b.AddedAt)
            .ToListAsync();

        return bookmarks.Select(b => new TorrentBookmarkDto(b)).ToList();
    }

    [HttpPost]
    public async Task<ActionResult<TorrentBookmarkDto>> Create([FromBody] TorrentBookmarkCreateDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.MagnetUrl))
            return BadRequest("Le magnet est requis.");

        string magnetUrl = dto.MagnetUrl.Trim();
        if (!Uri.TryCreate(magnetUrl, UriKind.Absolute, out Uri? magnetUri) ||
            !string.Equals(magnetUri.Scheme, "magnet", StringComparison.OrdinalIgnoreCase))
            return BadRequest("Le lien doit être un magnet valide.");
        string infoHash = DedupKey(magnetUrl);

        // Idempotent : un même torrent (même infohash) n'est mis de côté qu'une fois.
        TorrentBookmark? existing = await context.TorrentBookmarks
            .FirstOrDefaultAsync(b => b.InfoHash == infoHash);
        if (existing != null)
            return Ok(new TorrentBookmarkDto(existing));

        TorrentBookmark bookmark = new(
            dto.Title, dto.Size, dto.Seeders, dto.Leechers, dto.Indexer,
            magnetUrl, infoHash, dto.Category, dto.PublishDate);

        context.TorrentBookmarks.Add(bookmark);
        try
        {
            await context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (ex.InnerException is MySqlException { Number: 1062 })
        {
            context.Entry(bookmark).State = EntityState.Detached;
            existing = await context.TorrentBookmarks.FirstOrDefaultAsync(b => b.InfoHash == infoHash);
            if (existing is null) throw;
            return Ok(new TorrentBookmarkDto(existing));
        }

        return CreatedAtAction(nameof(GetAll), new { id = bookmark.Id }, new TorrentBookmarkDto(bookmark));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        TorrentBookmark? bookmark = await context.TorrentBookmarks.FindAsync(id);
        if (bookmark == null)
            return NotFound();

        context.TorrentBookmarks.Remove(bookmark);
        await context.SaveChangesAsync();

        return NoContent();
    }

    /// <summary>
    /// Clé de déduplication stable d'un magnet : son infohash btih (normalisé en minuscules),
    /// ou à défaut le SHA1 hex du magnet complet. Bornée à 64 caractères.
    /// </summary>
    private static string DedupKey(string magnetUrl)
    {
        if (Uri.TryCreate(magnetUrl, UriKind.Absolute, out Uri? uri) &&
            QueryHelpers.ParseQuery(uri.Query).TryGetValue("xt", out var topics))
        {
            // Lire xt comme paramètre évite de confondre le nom du fichier (dn) avec
            // l'infohash et prend également en charge les valeurs encodées en URL.
            foreach (string? topic in topics)
            {
                if (topic?.StartsWith("urn:btih:", StringComparison.OrdinalIgnoreCase) != true) continue;
                string infoHash = topic[9..];
                if (infoHash.Length is > 0 and <= 64 && infoHash.All(char.IsAsciiLetterOrDigit))
                    return infoHash.ToLowerInvariant();
            }
        }

        byte[] hash = SHA1.HashData(Encoding.UTF8.GetBytes(magnetUrl));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}
