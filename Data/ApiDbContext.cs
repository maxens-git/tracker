using Microsoft.EntityFrameworkCore;
using Tracker.Models;

namespace Tracker.Data;

public class ApiDbContext : DbContext
{
    public ApiDbContext(DbContextOptions<ApiDbContext> options) : base(options)
    {
    }

    public DbSet<UserMedia> UserMedia { get; set; } = null!;
    public DbSet<UserEpisode> UserEpisodes { get; set; } = null!;
    public DbSet<MediaList> MediaLists { get; set; } = null!;
    public DbSet<MediaListItem> MediaListItems { get; set; } = null!;
    public DbSet<ActivityEvent> ActivityEvents { get; set; } = null!;
    public DbSet<AppSettings> Settings { get; set; } = null!;
    public DbSet<TrackedMediaRelease> TrackedMediaReleases { get; set; } = null!;
    public DbSet<ReleaseNotification> ReleaseNotifications { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<UserMedia>()
            .HasIndex(m => new { m.TmdbId, m.MediaType })
            .IsUnique();

        modelBuilder.Entity<UserEpisode>()
            .HasIndex(e => new { e.ShowTmdbId, e.SeasonNumber, e.EpisodeNumber })
            .IsUnique();

        modelBuilder.Entity<MediaList>()
            .HasIndex(ml => ml.Name)
            .IsUnique();

        modelBuilder.Entity<MediaListItem>()
            .HasIndex(i => new { i.MediaListId, i.TmdbId, i.MediaType })
            .IsUnique();

        modelBuilder.Entity<MediaListItem>()
            .HasOne(i => i.MediaList)
            .WithMany(ml => ml.Items)
            .HasForeignKey(i => i.MediaListId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<ActivityEvent>()
            .HasIndex(e => e.CreatedAt);

        modelBuilder.Entity<TrackedMediaRelease>()
            .HasIndex(m => new { m.TmdbId, m.MediaType })
            .IsUnique();

        modelBuilder.Entity<ReleaseNotification>()
            .HasIndex(n => new { n.TmdbId, n.MediaType, n.ReleaseKey })
            .IsUnique();
    }
}
