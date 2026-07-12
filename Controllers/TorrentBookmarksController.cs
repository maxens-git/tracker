using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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
public partial class TorrentBookmarksController(ApiDbContext context) : ControllerBase
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

        string infoHash = DedupKey(dto.MagnetUrl);

        // Idempotent : un même torrent (même infohash) n'est mis de côté qu'une fois.
        TorrentBookmark? existing = await context.TorrentBookmarks
            .FirstOrDefaultAsync(b => b.InfoHash == infoHash);
        if (existing != null)
            return Ok(new TorrentBookmarkDto(existing));

        TorrentBookmark bookmark = new(
            dto.Title, dto.Size, dto.Seeders, dto.Leechers, dto.Indexer,
            dto.MagnetUrl, infoHash, dto.Category, dto.PublishDate);

        context.TorrentBookmarks.Add(bookmark);
        await context.SaveChangesAsync();

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
        Match match = InfoHashRegex().Match(magnetUrl);
        if (match.Success)
            return match.Groups[1].Value.ToLowerInvariant();

        byte[] hash = SHA1.HashData(Encoding.UTF8.GetBytes(magnetUrl));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    [GeneratedRegex(@"urn:btih:([A-Za-z0-9]+)", RegexOptions.IgnoreCase)]
    private static partial Regex InfoHashRegex();
}
