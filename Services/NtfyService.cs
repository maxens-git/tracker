using System.Net.Http.Headers;
using System.Text;
using Tracker.Models;

namespace Tracker.Services;

public class NtfyService(HttpClient http)
{
    public async Task SendReleaseNotification(AppSettings settings, ReleaseCandidate release, CancellationToken cancellationToken)
    {
        if (!settings.NtfyEnabled || string.IsNullOrWhiteSpace(settings.NtfyUrl) || string.IsNullOrWhiteSpace(settings.NtfyTopic))
            return;

        string date = release.ReleaseDate.ToString("dd/MM/yyyy");
        string body = $"{release.ReleaseTitle} sort le {date}.";
        string title = $"Sortie Tracker: {release.MediaTitle}";
        string tags = release.MediaType == MediaType.Movie ? "movie_camera" : "tv";

        await Send(settings, title, body, tags, cancellationToken);
    }

    public Task SendTestNotification(AppSettings settings, CancellationToken cancellationToken) =>
        Send(
            settings,
            "Test Tracker",
            $"Notification de test envoyée le {DateTime.Now:dd/MM/yyyy à HH:mm}.",
            "test_tube",
            cancellationToken);

    private async Task Send(AppSettings settings, string title, string body, string tags, CancellationToken cancellationToken)
    {
        Uri endpoint = BuildEndpoint(settings.NtfyUrl!, settings.NtfyTopic!);
        using HttpRequestMessage request = new(HttpMethod.Post, endpoint)
        {
            Content = new StringContent(body, Encoding.UTF8, "text/plain")
        };
        request.Headers.Add("Title", EncodeHeader(title));
        request.Headers.Add("Tags", tags);

        if (!string.IsNullOrWhiteSpace(settings.NtfyToken))
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", settings.NtfyToken);

        using HttpResponseMessage response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();
    }

    /// <summary>
    /// Les en-têtes HTTP sont transmis en Latin-1 : un titre accentué ou non-latin
    /// arriverait illisible côté ntfy. On encode donc en RFC 2047 (=?UTF-8?B?...?=)
    /// dès qu'un caractère non-ASCII est présent ; sinon on laisse la valeur brute.
    /// </summary>
    private static string EncodeHeader(string value)
    {
        if (value.All(c => c < 128))
            return value;

        string base64 = Convert.ToBase64String(Encoding.UTF8.GetBytes(value));
        return $"=?UTF-8?B?{base64}?=";
    }

    private static Uri BuildEndpoint(string baseUrl, string topic)
    {
        string cleanBase = baseUrl.Trim().TrimEnd('/');
        string cleanTopic = Uri.EscapeDataString(topic.Trim().Trim('/'));
        return new Uri($"{cleanBase}/{cleanTopic}");
    }
}
