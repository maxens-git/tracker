using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Tracker.Data;
using Tracker.Options;
using Tracker.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<ConnectionStringsOptions>(builder.Configuration.GetSection(ConnectionStringsOptions.SectionName));
builder.Services.Configure<TMDbOptions>(builder.Configuration.GetSection(TMDbOptions.SectionName));
builder.Services.Configure<JustWatchOptions>(builder.Configuration.GetSection(JustWatchOptions.SectionName));
builder.Services.Configure<LoggingOptions>(builder.Configuration.GetSection(LoggingOptions.SectionName));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var connectionStringsOptions = builder.Configuration.GetSection(ConnectionStringsOptions.SectionName).Get<ConnectionStringsOptions>();
var connectionString = connectionStringsOptions?.DefaultConnection ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection non configuré dans appsettings.json");

builder.Services.AddDbContext<ApiDbContext>(options =>
    options.UseMySql(
        connectionString,
        ServerVersion.AutoDetect(connectionString)
    )
);

builder.Services.AddHttpClient<TMDbService>();
builder.Services.AddScoped<TMDbService>(sp =>
{
    var httpClient = sp.GetRequiredService<IHttpClientFactory>().CreateClient();
    var tmdbOptions = sp.GetRequiredService<IOptions<TMDbOptions>>().Value;
    if (string.IsNullOrEmpty(tmdbOptions.ApiKey))
        throw new InvalidOperationException("TMDb:ApiKey non configuré dans appsettings.json");
    return new TMDbService(httpClient, tmdbOptions.ApiKey);
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var context = services.GetRequiredService<ApiDbContext>();
        var tmdbService = services.GetRequiredService<TMDbService>();
        var logger = services.GetRequiredService<ILogger<Program>>();
        var justWatchOptions = services.GetRequiredService<IOptions<JustWatchOptions>>().Value;
        
        await DbInitializer.InitializeAsync(context, tmdbService, logger, justWatchOptions.ExportFilePath);
        
        logger.LogInformation("Base de données initialisée avec succès.");
    }
    catch (Exception ex)
    {
        var logger = services.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "Une erreur est survenue lors de l'initialisation de la BDD.");
    }
}

app.UseAuthorization();
app.MapControllers();

app.Run();