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
builder.Services.AddScoped<IcsCalendarService>();
builder.Services.AddMemoryCache();
builder.Services.AddHttpClient<TmdbReleaseService>();
builder.Services.AddHttpClient<NtfyService>();
builder.Services.AddHostedService<ReleaseNotificationWorker>();

var app = builder.Build();

app.UseDefaultFiles();
app.UseStaticFiles();
app.UseRouting();
app.UseCors("AllowAngular");

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
