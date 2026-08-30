using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Tracker;
using Tracker.Data;
using Tracker.Options;
using Tracker.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ConnectionStringsOptions>(builder.Configuration.GetSection(ConnectionStringsOptions.SectionName));

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHttpContextAccessor();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAngular", policy =>
    {
        policy.WithOrigins("http://localhost:4200")
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var connectionStringsOptions = builder.Configuration.GetSection(ConnectionStringsOptions.SectionName).Get<ConnectionStringsOptions>();
var connectionString = connectionStringsOptions?.DefaultConnection ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection non configuré dans appsettings.json");

// Logger minimal pour la phase de démarrage : le conteneur d'injection n'existe pas encore.
using var startupLoggerFactory = LoggerFactory.Create(logging => logging.AddConfiguration(builder.Configuration.GetSection("Logging")).AddConsole());
var startupLogger = startupLoggerFactory.CreateLogger("Tracker.Startup");

var serverVersion = await DatabaseServerVersionResolver.ResolveAsync(
    connectionString, connectionStringsOptions?.ServerVersion, startupLogger);

builder.Services.AddDbContext<ApiDbContext>(options =>
    options.UseMySql(
        connectionString,
        serverVersion,
        // Coupure réseau ou redémarrage de MySQL : on retente la commande au lieu de
        // faire remonter l'erreur jusqu'au client.
        mySql => mySql.EnableRetryOnFailure(
            maxRetryCount: 10,
            maxRetryDelay: TimeSpan.FromSeconds(30),
            errorNumbersToAdd: null)
    )
);

builder.Services.AddSingleton<DatabaseInitializer>();

builder.Services.AddScoped<UserMediaService>();
builder.Services.AddScoped<MediaListService>();
builder.Services.AddScoped<StatsService>();
builder.Services.AddScoped<ActivityService>();
builder.Services.AddScoped<SystemLogService>();
builder.Services.AddSingleton<SystemLogQueue>();
builder.Services.AddSingleton<ILoggerProvider, DatabaseLoggerProvider>();
builder.Services.AddHostedService<SystemLogWriterService>();
builder.Services.AddHttpClient<SeenMediaMetadataBackfillService>();
builder.Services.AddScoped<IcsCalendarService>();
builder.Services.AddScoped<FavoriteTheaterService>();
builder.Services.AddMemoryCache();
builder.Services.AddHttpClient<TmdbReleaseService>();
builder.Services.AddHttpClient<NtfyService>();
builder.Services.AddHttpClient<ProwlarrService>();
builder.Services.AddHttpClient<AllDebridService>();
// Allociné rejette/limite les User-Agent non-navigateur : on se présente comme Chrome.
builder.Services.AddHttpClient<AllocineService>(client =>
{
    client.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/124.0 Safari/537.36");
    client.DefaultRequestHeaders.TryAddWithoutValidation("Accept-Language", "fr-FR,fr;q=0.9");
});
builder.Services.AddHostedService<ReleaseNotificationWorker>();

var app = builder.Build();

if (args.Contains("--backfill-seen-media-metadata"))
{
    using var scope = app.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<ApiDbContext>();
    await context.Database.MigrateAsync();

    var backfill = scope.ServiceProvider.GetRequiredService<SeenMediaMetadataBackfillService>();
    await backfill.Run(BackfillSeenMediaMetadataOptions.FromArgs(args));
    return;
}

app.UseDefaultFiles();
app.UseStaticFiles();
app.UseRouting();
app.UseCors("AllowAngular");
app.UseMiddleware<RequestLogMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Migrations et seed : on réessaie pendant 20 s avant d'ouvrir le port, puis en tâche de fond
// sans limite. Une base indisponible retarde le service, elle ne fait plus tomber l'API.
var databaseInitializer = app.Services.GetRequiredService<DatabaseInitializer>();
using var startupDatabaseTimeout = CancellationTokenSource.CreateLinkedTokenSource(app.Lifetime.ApplicationStopping);
startupDatabaseTimeout.CancelAfter(TimeSpan.FromSeconds(20));

if (!await databaseInitializer.TryInitializeAsync(maxAttempts: 0, startupDatabaseTimeout.Token))
{
    app.Logger.LogError("Base de données injoignable : l'API démarre quand même et réessaiera en arrière-plan.");
    _ = Task.Run(() => databaseInitializer.TryInitializeAsync(maxAttempts: 0, app.Lifetime.ApplicationStopping));
}

app.MapControllers();
app.MapFallbackToFile("/index.html");

app.Run();
