using Microsoft.EntityFrameworkCore;
using MySqlConnector;

namespace Tracker.Services;

/// <summary>
/// Résout la version du serveur MySQL sans faire tomber le démarrage : <c>ServerVersion.AutoDetect</c>
/// ouvre une connexion et lève une exception si la base est injoignable. On réessaie quelques fois,
/// puis on se rabat sur la version configurée (<c>ConnectionStrings:ServerVersion</c>) ou, à défaut,
/// sur une valeur raisonnable — l'API doit démarrer même si MySQL redémarre au même moment.
/// </summary>
public static class DatabaseServerVersionResolver
{
    private const int Attempts = 2;
    private const uint ProbeTimeoutSeconds = 3;
    private static readonly TimeSpan RetryDelay = TimeSpan.FromSeconds(1);
    private static readonly ServerVersion Fallback = new MySqlServerVersion(new Version(8, 0, 0));

    public static async Task<ServerVersion> ResolveAsync(
        string connectionString,
        string? configuredVersion,
        ILogger logger,
        CancellationToken cancellationToken = default)
    {
        if (!string.IsNullOrWhiteSpace(configuredVersion))
        {
            try
            {
                ServerVersion configured = ServerVersion.Parse(configuredVersion);
                logger.LogInformation("Version du serveur MySQL fixée par configuration : {Version}.", configured);
                return configured;
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex,
                    "ConnectionStrings:ServerVersion « {Value} » illisible, retour à la détection automatique.",
                    configuredVersion);
            }
        }

        // Sonde à délai court : sans cela, un serveur injoignable fait attendre le
        // timeout de connexion complet (15 s par défaut) à chaque tentative.
        string probeConnectionString = WithShortTimeout(connectionString);

        for (int attempt = 1; attempt <= Attempts; attempt++)
        {
            try
            {
                return await ServerVersion.AutoDetectAsync(probeConnectionString);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex,
                    "Détection de la version du serveur échouée (tentative {Attempt}/{Attempts}).",
                    attempt, Attempts);

                if (attempt < Attempts)
                    await Task.Delay(RetryDelay, cancellationToken);
            }
        }

        logger.LogError(
            "Base injoignable au démarrage : on suppose {Version}. Renseignez ConnectionStrings:ServerVersion si le serveur diffère.",
            Fallback);

        return Fallback;
    }

    private static string WithShortTimeout(string connectionString)
    {
        try
        {
            return new MySqlConnectionStringBuilder(connectionString)
            {
                ConnectionTimeout = ProbeTimeoutSeconds,
            }.ConnectionString;
        }
        catch
        {
            return connectionString;
        }
    }
}
