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

builder.Services.AddDbContext<ApiDbContext>(options =>
    options.UseMySql(
        connectionString,
        ServerVersion.AutoDetect(connectionString)
    )
);

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
builder.Services.AddScoped<TheaterListService>();
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

using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<ApiDbContext>();
    await context.Database.MigrateAsync();

    await DbSeeder.SeedSystemListsAsync(context);

    if (app.Configuration.GetValue<bool>("JustWatch:EnableImport"))
        await DbSeeder.SeedFromJustWatchAsync(context, app.Environment.ContentRootPath);
}

app.MapControllers();
app.MapFallbackToFile("/index.html");

app.Run();
