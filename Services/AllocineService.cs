using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Caching.Memory;
using Tracker.ModelsDTO;

namespace Tracker.Services;

/// <summary>
/// Récupère les séances de cinéma depuis l'endpoint JSON interne d'Allociné
/// (non officiel, non documenté) :
///   https://www.allocine.fr/_/showtimes/theater-&lt;CODE&gt;/d-&lt;YYYY-MM-DD&gt;/[p-&lt;N&gt;/]
/// Avantages sur le scraping HTML : réponse structurée (version, format, billetterie,
/// affiche), navigation par date et pagination pour les gros cinémas.
///
/// Le JSON ne porte pas le nom/adresse du cinéma : on les lit en parallèle dans le
/// bloc JSON-LD "MovieTheater" de la page publique de la salle.
///
/// API susceptible de casser sans préavis — à utiliser avec parcimonie.
/// </summary>
public partial class AllocineService(HttpClient http, IMemoryCache cache, ILogger<AllocineService> logger)
{
    private const int MaxPages = 5;      // garde-fou anti-boucle sur la pagination
    private const int MaxTheaters = 8;   // garde-fou anti-abus sur les listes de salles

    // Le programme d'une journée bouge peu : on évite de re-frapper Allociné à chaque consultation.
    private static readonly TimeSpan ShowtimesTtl = TimeSpan.FromMinutes(20);
    // Nom/adresse d'une salle sont quasi statiques : cache long, appel HTTP séparé économisé.
    private static readonly TimeSpan TheaterInfoTtl = TimeSpan.FromHours(12);

    /// <summary>Valide et normalise le code salle publiquement (réutilisé pour valider les listes).</summary>
    public static string NormalizeCode(string? code) => NormalizeTheaterCode(code);

    /// <summary>
    /// Programme d'une journée pour plusieurs salles. Chaque salle passe par le cache et est
    /// chargée en parallèle ; une salle en échec est ignorée (loggée) plutôt que de tout faire échouer.
    /// Les codes invalides lèvent (comme en mono-salle) : c'est une erreur d'entrée, pas un aléa réseau.
    /// </summary>
    public async Task<IReadOnlyList<TheaterShowtimesDto>> GetMultipleShowtimes(
        IEnumerable<string> codes, string? date, CancellationToken cancellationToken)
    {
        // Normalise (valide) et déduplique en conservant l'ordre, puis plafonne.
        var normalized = new List<string>();
        var seen = new HashSet<string>();
        foreach (string raw in codes)
        {
            string code = NormalizeTheaterCode(raw);
            if (seen.Add(code)) normalized.Add(code);
            if (normalized.Count >= MaxTheaters) break;
        }

        TheaterShowtimesDto?[] results = await Task.WhenAll(
            normalized.Select(code => GetShowtimesOrNull(code, date, cancellationToken)));

        return results.Where(r => r is not null).Select(r => r!).ToList();
    }

    private async Task<TheaterShowtimesDto?> GetShowtimesOrNull(string code, string? date, CancellationToken cancellationToken)
    {
        try
        {
            return await GetShowtimes(code, date, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Séances Allociné indisponibles pour {Code} (ignoré dans la liste).", code);
            return null;
        }
    }

    public async Task<TheaterShowtimesDto> GetShowtimes(string code, string? date, CancellationToken cancellationToken)
    {
        code = NormalizeTheaterCode(code);
        string day = NormalizeDate(date);

        // GetOrCreateAsync ne met en cache que les fetch réussis : une exception ne cache rien.
        return (await cache.GetOrCreateAsync($"showtimes:{code}:{day}", entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = ShowtimesTtl;
            return FetchShowtimes(code, day, cancellationToken);
        }))!;
    }

    private async Task<TheaterShowtimesDto> FetchShowtimes(string code, string day, CancellationToken cancellationToken)
    {
        // Les métadonnées de la salle viennent d'une autre page : chargées en parallèle des séances.
        Task<TheaterDto> theaterTask = GetTheaterInfo(code, cancellationToken);

        using JsonDocument first = await FetchJson(ShowtimesUrl(code, day, 1), cancellationToken);
        JsonElement root = first.RootElement;

        var movies = new List<ShowtimeMovieDto>();
        CollectMovies(root, movies);

        int totalPages = 1;
        if (root.TryGetProperty("pagination", out JsonElement pag) &&
            pag.TryGetProperty("totalPages", out JsonElement tp) && tp.ValueKind == JsonValueKind.Number)
            totalPages = Math.Min(tp.GetInt32(), MaxPages);

        for (int p = 2; p <= totalPages; p++)
        {
            using JsonDocument page = await FetchJson(ShowtimesUrl(code, day, p), cancellationToken);
            CollectMovies(page.RootElement, movies);
        }

        string? nextDate = ReadString(root, "nextDate");

        return new TheaterShowtimesDto(
            await theaterTask,
            day,
            nextDate,
            MergeDuplicateMovies(movies).Where(m => m.Shows.Count > 0).ToList());
    }

    /// <summary>
    /// Allociné peut lister un même film en plusieurs résultats (selon les pages ou les
    /// versions) : on fusionne par identité (internalId, à défaut le titre) en dédupliquant
    /// les séances par id, pour éviter des films et des séances en double côté frontend.
    /// </summary>
    private static List<ShowtimeMovieDto> MergeDuplicateMovies(List<ShowtimeMovieDto> movies)
    {
        var byKey = new Dictionary<string, ShowtimeMovieDto>();
        var order = new List<string>();

        foreach (ShowtimeMovieDto movie in movies)
        {
            string key = movie.Id is long id ? $"id:{id}" : $"title:{movie.Title}";
            if (!byKey.TryGetValue(key, out ShowtimeMovieDto? existing))
            {
                byKey[key] = movie;
                order.Add(key);
                continue;
            }

            var shows = new List<ShowtimeDto>(existing.Shows);
            var seen = new HashSet<string>(shows.Select(s => s.Id));
            foreach (ShowtimeDto s in movie.Shows)
                if (!string.IsNullOrEmpty(s.Id) && seen.Add(s.Id)) shows.Add(s);
            shows.Sort((a, b) => string.CompareOrdinal(a.Iso, b.Iso));

            byKey[key] = existing with { Shows = shows, Poster = existing.Poster ?? movie.Poster };
        }

        return order.Select(k => byKey[k]).ToList();
    }

    /// <summary>
    /// Valide et normalise le code salle (une lettre + 3 à 5 chiffres, ex. P0057).
    /// Indispensable : le code est interpolé tel quel dans les URLs Allociné.
    /// </summary>
    private static string NormalizeTheaterCode(string? code)
    {
        code = (code ?? "").Trim().ToUpperInvariant();
        if (!TheaterCodePattern().IsMatch(code))
            throw new InvalidOperationException("Code cinéma invalide, attendu : une lettre suivie de chiffres (ex. P0057).");
        return code;
    }

    /// <summary>Valide la date (YYYY-MM-DD, interpolée dans l'URL) ; défaut : aujourd'hui.</summary>
    private static string NormalizeDate(string? date)
    {
        if (string.IsNullOrWhiteSpace(date)) return TodayIso();
        return DateOnly.TryParseExact(date.Trim(), "yyyy-MM-dd", out DateOnly parsed)
            ? parsed.ToString("yyyy-MM-dd")
            : throw new InvalidOperationException("Date invalide, format attendu : YYYY-MM-DD.");
    }

    private static string ShowtimesUrl(string code, string date, int page) =>
        $"https://www.allocine.fr/_/showtimes/theater-{code}/d-{date}/{(page > 1 ? $"p-{page}/" : "")}";

    private static string TheaterPageUrl(string code) =>
        $"https://www.allocine.fr/seance/salle_gen_csalle={code}.html";

    private static string TodayIso() => DateTime.Now.ToString("yyyy-MM-dd");

    private async Task<JsonDocument> FetchJson(string url, CancellationToken cancellationToken)
    {
        using HttpRequestMessage request = new(HttpMethod.Get, url);
        request.Headers.TryAddWithoutValidation("Accept", "application/json");

        using HttpResponseMessage response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        await using Stream stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        return await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
    }

    /// <summary>Normalise chaque résultat (film + ses séances) de la page dans <paramref name="movies"/>.</summary>
    private static void CollectMovies(JsonElement root, List<ShowtimeMovieDto> movies)
    {
        if (!root.TryGetProperty("results", out JsonElement results) || results.ValueKind != JsonValueKind.Array)
            return;

        foreach (JsonElement result in results.EnumerateArray())
        {
            ShowtimeMovieDto? movie = NormalizeMovie(result);
            if (movie is not null) movies.Add(movie);
        }
    }

    private static ShowtimeMovieDto? NormalizeMovie(JsonElement result)
    {
        if (!result.TryGetProperty("movie", out JsonElement mv) || mv.ValueKind != JsonValueKind.Object)
            return null;

        var shows = new List<ShowtimeDto>();
        var seen = new HashSet<string>();
        // showtimes = { original: [...], original_st: [...], multiple: [...], ... }
        if (result.TryGetProperty("showtimes", out JsonElement showtimes) && showtimes.ValueKind == JsonValueKind.Object)
        {
            foreach (JsonProperty group in showtimes.EnumerateObject())
            {
                if (group.Value.ValueKind != JsonValueKind.Array) continue;
                foreach (JsonElement st in group.Value.EnumerateArray())
                {
                    ShowtimeDto show = NormalizeShow(st);
                    if (!string.IsNullOrEmpty(show.Id) && seen.Add(show.Id))
                        shows.Add(show);
                }
            }
        }

        shows.Sort((a, b) => string.CompareOrdinal(a.Iso, b.Iso));

        long? id = ReadLong(mv, "internalId") ?? ReadLong(mv, "id");
        string title = ReadString(mv, "title") ?? ReadString(mv, "originalTitle") ?? "Sans titre";

        string? poster = null;
        if (mv.TryGetProperty("poster", out JsonElement posterEl) && posterEl.ValueKind == JsonValueKind.Object)
            poster = ReadString(posterEl, "url");

        return new ShowtimeMovieDto(
            Id: id,
            Title: title,
            Poster: poster,
            Runtime: ReadString(mv, "runtime"),
            Genres: ReadGenres(mv),
            Url: id is long i ? $"https://www.allocine.fr/film/fichefilm_gen_cfilm={i}.html" : null,
            Shows: shows);
    }

    private static ShowtimeDto NormalizeShow(JsonElement st)
    {
        string iso = ReadString(st, "startsAt") ?? "";
        return new ShowtimeDto(
            Id: ReadLong(st, "internalId")?.ToString() ?? "",
            Iso: iso,
            Date: iso.Length >= 10 ? iso[..10] : "",
            Time: iso.Length >= 16 ? iso[11..16] : "",
            Version: MapVersion(ReadString(st, "diffusionVersion")),
            Formats: MapFormats(st),
            IsPreview: st.TryGetProperty("isPreview", out JsonElement pv) && pv.ValueKind == JsonValueKind.True,
            TicketingUrl: ReadTicketingUrl(st));
    }

    /// <summary>DUBBED/LOCAL (VF d'origine) -> VF ; ORIGINAL -> VO.</summary>
    private static string? MapVersion(string? diffusionVersion) => diffusionVersion switch
    {
        "ORIGINAL" => "VO",
        "DUBBED" or "LOCAL" => "VF",
        _ => null,
    };

    /// <summary>Formats "marquants" : on ignore la projection DIGITAL classique.</summary>
    private static List<string> MapFormats(JsonElement st)
    {
        var formats = new List<string>();

        void Add(string? raw)
        {
            string v = NormalizeFormat(raw);
            // DIGITAL = projection numérique standard ; PLF = "grande salle premium" générique :
            // ni l'un ni l'autre n'apporte d'info marquante, on ne les affiche pas.
            if (v.Length > 0 && v != "DIGITAL" && v != "PLF" && !formats.Contains(v)) formats.Add(v);
        }

        foreach (string p in ReadStringArray(st, "projection")) Add(p); // IMAX, IMAX_3D...
        foreach (string e in ReadStringArray(st, "experience")) Add(e); // DOLBY_CINEMA, PLF, 4DX...

        // picture peut être une chaîne ("THREE_D") ou un tableau selon les séances.
        bool threeD = ReadStringArray(st, "picture").Contains("THREE_D") ||
                      ReadString(st, "picture") == "THREE_D";
        if (threeD) Add("3D");

        return formats;
    }

    /// <summary>
    /// Allociné préfixe ses énumérations d'expérience/format par un namespace technique
    /// (E_ = Experience, F_ = Format) : « E_4DX » -> « 4DX », « F_3D » -> « 3D ».
    /// On retire ce préfixe, sans intérêt pour l'affichage.
    /// </summary>
    private static string NormalizeFormat(string? raw)
    {
        string v = (raw ?? "").Trim();
        return v.StartsWith("E_") || v.StartsWith("F_") ? v[2..] : v;
    }

    private static string? ReadTicketingUrl(JsonElement st)
    {
        if (st.TryGetProperty("data", out JsonElement data) && data.ValueKind == JsonValueKind.Object &&
            data.TryGetProperty("ticketing", out JsonElement ticketing) && ticketing.ValueKind == JsonValueKind.Array &&
            ticketing.GetArrayLength() > 0)
        {
            JsonElement first = ticketing[0];
            if (first.TryGetProperty("urls", out JsonElement urls) && urls.ValueKind == JsonValueKind.Array &&
                urls.GetArrayLength() > 0 && urls[0].ValueKind == JsonValueKind.String)
                return urls[0].GetString();
        }
        return null;
    }

    /// <summary>Cinéma dont seul le code est connu (métadonnées indisponibles).</summary>
    private static TheaterDto UnknownTheater(string code) => new(code, null, null, null, null, null);

    /// <summary>Infos cinéma depuis le bloc JSON-LD MovieTheater de la page publique (échoue en silence, cache long).</summary>
    private async Task<TheaterDto> GetTheaterInfo(string code, CancellationToken cancellationToken)
    {
        return (await cache.GetOrCreateAsync($"theater:{code}", async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TheaterInfoTtl;
            return await FetchTheaterInfo(code, cancellationToken);
        }))!;
    }

    private async Task<TheaterDto> FetchTheaterInfo(string code, CancellationToken cancellationToken)
    {
        try
        {
            using HttpRequestMessage request = new(HttpMethod.Get, TheaterPageUrl(code));
            using HttpResponseMessage response = await http.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode) return UnknownTheater(code);

            string html = await response.Content.ReadAsStringAsync(cancellationToken);
            Match m = MovieTheaterLdJson().Match(html);
            if (!m.Success) return UnknownTheater(code);

            using JsonDocument ld = JsonDocument.Parse(m.Groups[1].Value);
            JsonElement root = ld.RootElement;

            string? address = null, postalCode = null, city = null;
            if (root.TryGetProperty("address", out JsonElement addr) && addr.ValueKind == JsonValueKind.Object)
            {
                address = ReadString(addr, "streetAddress");
                postalCode = ReadString(addr, "postalCode");
                city = ReadString(addr, "addressLocality");
            }

            return new TheaterDto(
                code,
                ReadString(root, "name"),
                address,
                postalCode,
                city,
                ReadString(root, "image"));
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "Métadonnées cinéma {Code} indisponibles.", code);
            return UnknownTheater(code);
        }
    }

    private static IReadOnlyList<string> ReadGenres(JsonElement movie)
    {
        if (!movie.TryGetProperty("genres", out JsonElement genres) || genres.ValueKind != JsonValueKind.Array)
            return [];

        var list = new List<string>();
        foreach (JsonElement g in genres.EnumerateArray())
        {
            string? name = g.ValueKind == JsonValueKind.String
                ? g.GetString()
                : ReadString(g, "translate") ?? ReadString(g, "name");
            if (!string.IsNullOrWhiteSpace(name)) list.Add(name);
        }
        return list;
    }

    [GeneratedRegex("^[A-Z][0-9]{3,5}$")]
    private static partial Regex TheaterCodePattern();

    // Le bloc peut contenir plusieurs types ; on cible celui portant "@type":"MovieTheater".
    [GeneratedRegex(
        "<script type=\"application/ld\\+json\">\\s*(\\{.*?\"@type\"\\s*:\\s*\"MovieTheater\".*?\\})\\s*</script>",
        RegexOptions.Singleline)]
    private static partial Regex MovieTheaterLdJson();

    private static string? ReadString(JsonElement element, string name) =>
        element.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    private static long? ReadLong(JsonElement element, string name) =>
        element.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.Number
            ? value.GetInt64()
            : null;

    private static IReadOnlyList<string> ReadStringArray(JsonElement element, string name)
    {
        if (!element.TryGetProperty(name, out JsonElement value) || value.ValueKind != JsonValueKind.Array)
            return [];

        var list = new List<string>();
        foreach (JsonElement item in value.EnumerateArray())
            if (item.ValueKind == JsonValueKind.String) list.Add(item.GetString()!);
        return list;
    }
}
