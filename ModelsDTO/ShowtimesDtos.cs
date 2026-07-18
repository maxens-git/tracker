namespace Tracker.ModelsDTO;

/// <summary>Une séance d'un film dans un cinéma, telle qu'exposée au frontend.</summary>
public record ShowtimeDto(
    string Id,
    string Iso,          // horodatage complet "2026-07-16T09:45:00"
    string Date,         // "2026-07-16"
    string Time,         // "09:45"
    string? Version,     // "VO" / "VF" (null si inconnu)
    IReadOnlyList<string> Formats, // IMAX, DOLBY_CINEMA, PLF, 3D...
    bool IsPreview,      // avant-première
    string? TicketingUrl);

/// <summary>Un film à l'affiche dans un cinéma pour une date, avec ses séances.</summary>
public record ShowtimeMovieDto(
    long? Id,
    string Title,
    string? Poster,
    string? Runtime,     // déjà formaté par Allociné, ex. "2h 53min"
    IReadOnlyList<string> Genres,
    string? Url,
    IReadOnlyList<ShowtimeDto> Shows);

/// <summary>Métadonnées d'un cinéma (issues du JSON-LD de sa page publique).</summary>
public record TheaterDto(
    string Code,
    string? Name,
    string? Address,
    string? PostalCode,
    string? City,
    string? Image);

/// <summary>Programme d'un cinéma pour une journée donnée.</summary>
public record TheaterShowtimesDto(
    TheaterDto Theater,
    string Date,
    string? NextDate,    // prochaine date avec des séances (pour "jour suivant")
    IReadOnlyList<ShowtimeMovieDto> Movies);
