using Microsoft.EntityFrameworkCore;
using Tracker.Data;

namespace Tracker.Services;

/// <summary>
/// Applique les migrations puis le seed, en réessayant tant que la base n'est pas joignable.
/// Une base momentanément absente (redémarrage MySQL, coupure réseau) ne doit pas tuer l'API :
/// on démarre quand même et on retente en arrière-plan jusqu'à ce qu'elle réponde.
/// </summary>
public class DatabaseInitializer(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    IHostEnvironment environment,
    ILogger<DatabaseInitializer> logger)
{
    private static readonly TimeSpan FirstDelay = TimeSpan.FromSeconds(2);
    private static readonly TimeSpan MaxDelay = TimeSpan.FromSeconds(30);

    /// <summary>Vrai une fois les migrations et le seed passés.</summary>
    public bool IsReady { get; private set; }

    /// <param name="maxAttempts">Nombre d'essais, ou 0 pour réessayer sans limite.</param>
    /// <returns>Vrai si la base est prête.</returns>
    public async Task<bool> TryInitializeAsync(int maxAttempts, CancellationToken cancellationToken)
    {
        TimeSpan delay = FirstDelay;

        for (int attempt = 1; maxAttempts <= 0 || attempt <= maxAttempts; attempt++)
        {
            try
            {
                await Initialize(cancellationToken);
                IsReady = true;

                if (attempt > 1)
                    logger.LogInformation("Base de données prête après {Attempts} tentative(s).", attempt);

                return true;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                return false;
            }
            catch (Exception ex)
            {
                bool lastAttempt = maxAttempts > 0 && attempt == maxAttempts;

                logger.LogWarning(ex,
                    "Initialisation de la base échouée (tentative {Attempt}){Retry}.",
                    attempt,
                    lastAttempt ? "" : $", nouvel essai dans {delay.TotalSeconds:0}s");

                if (lastAttempt)
                    return false;

                try
                {
                    await Task.Delay(delay, cancellationToken);
                }
                catch (OperationCanceledException)
                {
                    return false;
                }

                delay = TimeSpan.FromTicks(Math.Min(delay.Ticks * 2, MaxDelay.Ticks));
            }
        }

        return false;
    }

    private async Task Initialize(CancellationToken cancellationToken)
    {
        using IServiceScope scope = scopeFactory.CreateScope();
        ApiDbContext context = scope.ServiceProvider.GetRequiredService<ApiDbContext>();

        await context.Database.MigrateAsync(cancellationToken);

        await DbSeeder.SeedSystemListsAsync(context);

        if (configuration.GetValue<bool>("JustWatch:EnableImport"))
            await DbSeeder.SeedFromJustWatchAsync(context, environment.ContentRootPath);
    }
}
