using Microsoft.AspNetCore.Mvc;
using Tracker.Models.TMDbResponses;
using Tracker.ModelsDTO;
using Tracker.Services;

namespace Tracker.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TrailersController : ControllerBase
{
    private readonly TMDbService _tmdbService;

    public TrailersController(TMDbService tmdbService)
    {
        _tmdbService = tmdbService;
    }

    [HttpGet("movie/{tmdbId}")]
    public async Task<ActionResult<TrailersResponseDto>> GetMovieTrailers(int tmdbId)
    {
        TMDbVideosResponse? frVideos = await _tmdbService.GetMovieVideosAsync(tmdbId, "fr-FR");
        TMDbVideosResponse? enVideos = await _tmdbService.GetMovieVideosAsync(tmdbId, "en-US");

        List<TrailerDto> trailers = new();

        if (frVideos?.Results != null)
        {
            trailers.AddRange(frVideos.Results
                .Where(v => v.Site == "YouTube" && (v.Type == "Trailer" || v.Type == "Teaser"))
                .Select(v => MapToDto(v)));
        }

        if (enVideos?.Results != null)
        {
            var existingKeys = trailers.Select(t => t.Key).ToHashSet();
            trailers.AddRange(enVideos.Results
                .Where(v => v.Site == "YouTube" && (v.Type == "Trailer" || v.Type == "Teaser") && !existingKeys.Contains(v.Key))
                .Select(v => MapToDto(v)));
        }

        trailers = trailers
            .OrderByDescending(t => t.Official)
            .ThenByDescending(t => t.Type == "Trailer")
            .ThenByDescending(t => t.Language == "fr")
            .ToList();

        return Ok(new TrailersResponseDto
        {
            TmdbId = tmdbId,
            Trailers = trailers
        });
    }

    [HttpGet("show/{tmdbId}")]
    public async Task<ActionResult<TrailersResponseDto>> GetShowTrailers(int tmdbId)
    {
        TMDbVideosResponse? frVideos = await _tmdbService.GetShowVideosAsync(tmdbId, "fr-FR");
        TMDbVideosResponse? enVideos = await _tmdbService.GetShowVideosAsync(tmdbId, "en-US");

        List<TrailerDto> trailers = new();

        if (frVideos?.Results != null)
        {
            trailers.AddRange(frVideos.Results
                .Where(v => v.Site == "YouTube" && (v.Type == "Trailer" || v.Type == "Teaser"))
                .Select(v => MapToDto(v)));
        }

        if (enVideos?.Results != null)
        {
            var existingKeys = trailers.Select(t => t.Key).ToHashSet();
            trailers.AddRange(enVideos.Results
                .Where(v => v.Site == "YouTube" && (v.Type == "Trailer" || v.Type == "Teaser") && !existingKeys.Contains(v.Key))
                .Select(v => MapToDto(v)));
        }

        trailers = trailers
            .OrderByDescending(t => t.Official)
            .ThenByDescending(t => t.Type == "Trailer")
            .ThenByDescending(t => t.Language == "fr")
            .ToList();

        return Ok(new TrailersResponseDto
        {
            TmdbId = tmdbId,
            Trailers = trailers
        });
    }

    private static TrailerDto MapToDto(TMDbVideo video)
    {
        return new TrailerDto
        {
            Id = video.Id,
            Name = video.Name,
            Key = video.Key,
            Site = video.Site,
            Type = video.Type,
            Official = video.Official,
            Language = video.Iso639_1,
            PublishedAt = video.PublishedAt
        };
    }
}
